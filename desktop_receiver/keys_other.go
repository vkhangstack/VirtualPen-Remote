//go:build !linux && !windows

package main

import "errors"

// Other platforms (macOS) use mac_receiver instead; this stub only lets the
// package build and test on a dev machine.
func newKeySender() (keySender, error) {
	return nil, errors.New("nền tảng này không được hỗ trợ — trên macOS hãy dùng mac_receiver")
}
