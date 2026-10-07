package main

import (
	"fmt"

	"github.com/bendahl/uinput"
)

// Linux: a virtual keyboard via /dev/uinput. Works on both X11 and Wayland
// (unlike XTest/xdotool), but needs write access to /dev/uinput — see install-linux.sh.
type uinputSender struct{ kb uinput.Keyboard }

func newKeySender() (keySender, error) {
	kb, err := uinput.CreateKeyboard("/dev/uinput", []byte("VirtualPen Receiver"))
	if err != nil {
		return nil, fmt.Errorf("%w\n   Chạy ./install-linux.sh một lần (hoặc chạy receiver bằng sudo) để cấp quyền /dev/uinput", err)
	}
	return &uinputSender{kb: kb}, nil
}

func (s *uinputSender) Press(cmd Command) error {
	switch cmd {
	case CmdNext:
		return s.kb.KeyPress(uinput.KeyRight)
	case CmdPrev:
		return s.kb.KeyPress(uinput.KeyLeft)
	case CmdStart:
		return s.kb.KeyPress(uinput.KeyF5) // PowerPoint / LibreOffice Impress
	case CmdResume:
		return s.combo(uinput.KeyLeftshift, uinput.KeyF5)
	case CmdEnd:
		return s.kb.KeyPress(uinput.KeyEsc)
	case CmdBlack:
		return s.kb.KeyPress(uinput.KeyB)
	case CmdWhite:
		return s.kb.KeyPress(uinput.KeyW)
	}
	return nil
}

func (s *uinputSender) combo(modifier, key int) error {
	if err := s.kb.KeyDown(modifier); err != nil {
		return err
	}
	defer s.kb.KeyUp(modifier)
	return s.kb.KeyPress(key)
}

func (s *uinputSender) Close() { s.kb.Close() }
