//go:build linux || windows

package main

import (
	"fmt"

	"tinygo.org/x/bluetooth"
)

var (
	bleServiceUUID = bluetooth.NewUUID([16]byte{0x7A, 0x1C, 0x00, 0x01, 0x5B, 0x8E, 0x4C, 0x3A, 0x9F, 0x2D, 0x1E, 0x6B, 0x8A, 0x4C, 0x0D, 0x01})
	bleCommandUUID = bluetooth.NewUUID([16]byte{0x7A, 0x1C, 0x00, 0x02, 0x5B, 0x8E, 0x4C, 0x3A, 0x9F, 0x2D, 0x1E, 0x6B, 0x8A, 0x4C, 0x0D, 0x01})
)

// startBLE exposes a GATT service with one writable characteristic; the phone
// writes an ASCII command (e.g. "NEXT") to it. Linux uses BlueZ over D-Bus,
// Windows uses WinRT (which advertises the service itself).
func startBLE(onCommand func(string)) error {
	adapter := bluetooth.DefaultAdapter
	if err := adapter.Enable(); err != nil {
		return fmt.Errorf("không bật được Bluetooth: %w", err)
	}
	err := adapter.AddService(&bluetooth.Service{
		UUID: bleServiceUUID,
		Characteristics: []bluetooth.CharacteristicConfig{{
			UUID:  bleCommandUUID,
			Flags: bluetooth.CharacteristicWritePermission,
			WriteEvent: func(_ bluetooth.Connection, _ int, value []byte) {
				onCommand(string(value))
			},
		}},
	})
	if err != nil {
		return fmt.Errorf("không tạo được GATT service: %w", err)
	}
	adv := adapter.DefaultAdvertisement()
	if err := adv.Configure(bluetooth.AdvertisementOptions{
		LocalName:    "VirtualPen",
		ServiceUUIDs: []bluetooth.UUID{bleServiceUUID},
	}); err != nil {
		return fmt.Errorf("không cấu hình được quảng bá BLE: %w", err)
	}
	return adv.Start()
}
