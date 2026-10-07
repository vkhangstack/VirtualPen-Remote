package main

import "strings"

// Command is one of the whitelisted wire commands. Keep in sync with
// mobile_app/lib/protocol.dart and mac_receiver/Sources/PPTReceiver/KeySender.swift.
type Command string

const (
	CmdNext   Command = "NEXT"
	CmdPrev   Command = "PREV"
	CmdStart  Command = "START"  // play from first slide
	CmdResume Command = "RESUME" // play from current slide
	CmdEnd    Command = "END"
	CmdBlack  Command = "BLACK"
	CmdWhite  Command = "WHITE"
)

var commands = map[Command]bool{
	CmdNext: true, CmdPrev: true, CmdStart: true, CmdResume: true,
	CmdEnd: true, CmdBlack: true, CmdWhite: true,
}

// parseCommand returns the command for raw wire text, or false for anything
// outside the whitelist, so a client can never inject arbitrary keystrokes.
func parseCommand(raw string) (Command, bool) {
	cmd := Command(strings.ToUpper(strings.TrimSpace(raw)))
	return cmd, commands[cmd]
}
