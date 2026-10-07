package main

import "testing"

func TestParseCommand(t *testing.T) {
	for _, raw := range []string{"NEXT", "next\n", " PREV ", "START", "RESUME", "END", "BLACK", "WHITE\r"} {
		if _, ok := parseCommand(raw); !ok {
			t.Errorf("parseCommand(%q) rejected a whitelisted command", raw)
		}
	}
	for _, raw := range []string{"", "HELLO", "rm -rf /", "NEXT NEXT"} {
		if _, ok := parseCommand(raw); ok {
			t.Errorf("parseCommand(%q) accepted a non-whitelisted command", raw)
		}
	}
}
