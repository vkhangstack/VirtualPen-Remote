package main

import (
	"fmt"
	"unsafe"

	"golang.org/x/sys/windows"
)

var (
	user32      = windows.NewLazySystemDLL("user32.dll")
	procSendInp = user32.NewProc("SendInput")
)

const cpUTF8 = 65001

const (
	inputKeyboard    = 1
	keyEventExtended = 0x0001
	keyEventKeyUp    = 0x0002
	vkShift          = 0x10
	vkEscape         = 0x1B
	vkLeft           = 0x25
	vkRight          = 0x27
	vkB              = 0x42
	vkW              = 0x57
	vkF5             = 0x74
)

// keyboardInput mirrors the Win32 INPUT struct (keyboard variant) on 64-bit
// Windows: 4-byte type + padding, KEYBDINPUT, padded to the union's 32 bytes.
type keyboardInput struct {
	inputType   uint32
	_           uint32
	wVk         uint16
	wScan       uint16
	dwFlags     uint32
	time        uint32
	dwExtraInfo uintptr
	_           [8]byte
}

// Compile-time check: SendInput rejects the call if cbSize != sizeof(INPUT) (40).
var _ [40]byte = [unsafe.Sizeof(keyboardInput{})]byte{}

// Windows: synthetic keystrokes via SendInput, delivered to the foreground window.
type sendInputSender struct{}

func newKeySender() (keySender, error) { return sendInputSender{}, nil }

func (sendInputSender) Press(cmd Command) error {
	switch cmd {
	case CmdNext:
		return send(key(vkRight, true)...)
	case CmdPrev:
		return send(key(vkLeft, true)...)
	case CmdStart:
		return send(key(vkF5, false)...) // PowerPoint / LibreOffice Impress
	case CmdResume:
		return send(keyDown(vkShift, false), keyDown(vkF5, false), keyUp(vkF5, false), keyUp(vkShift, false))
	case CmdEnd:
		return send(key(vkEscape, false)...)
	case CmdBlack:
		return send(key(vkB, false)...)
	case CmdWhite:
		return send(key(vkW, false)...)
	}
	return nil
}

func (sendInputSender) Close() {}

func key(vk uint16, extended bool) []keyboardInput {
	return []keyboardInput{keyDown(vk, extended), keyUp(vk, extended)}
}

func keyDown(vk uint16, extended bool) keyboardInput {
	in := keyboardInput{inputType: inputKeyboard, wVk: vk}
	if extended { // arrow keys live on the extended key block
		in.dwFlags |= keyEventExtended
	}
	return in
}

func keyUp(vk uint16, extended bool) keyboardInput {
	in := keyDown(vk, extended)
	in.dwFlags |= keyEventKeyUp
	return in
}

func send(inputs ...keyboardInput) error {
	n, _, err := procSendInp.Call(uintptr(len(inputs)), uintptr(unsafe.Pointer(&inputs[0])), unsafe.Sizeof(inputs[0]))
	if int(n) != len(inputs) {
		return fmt.Errorf("SendInput: %v", err)
	}
	return nil
}

// Make Vietnamese/emoji log output readable in the classic console (cmd.exe).
func init() { windows.SetConsoleOutputCP(cpUTF8) }
