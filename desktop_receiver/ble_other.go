//go:build !linux && !windows

package main

import "errors"

func startBLE(func(string)) error { return errors.New("không hỗ trợ trên nền tảng này") }
