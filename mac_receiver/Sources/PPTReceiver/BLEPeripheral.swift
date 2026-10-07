import CoreBluetooth
import Foundation

/// Advertises a GATT service with a single writable characteristic.
/// The phone writes an ASCII command (e.g. "NEXT") to it.
final class BLEPeripheral: NSObject, CBPeripheralManagerDelegate {
    static let serviceUUID = CBUUID(string: "7A1C0001-5B8E-4C3A-9F2D-1E6B8A4C0D01")
    static let commandUUID = CBUUID(string: "7A1C0002-5B8E-4C3A-9F2D-1E6B8A4C0D01")

    private var manager: CBPeripheralManager!
    private let onCommand: (String) -> Void

    init(onCommand: @escaping (String) -> Void) {
        self.onCommand = onCommand
        super.init()
        manager = CBPeripheralManager(delegate: self, queue: .main)
    }

    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        guard peripheral.state == .poweredOn else {
            print("🔵 Bluetooth unavailable (state \(peripheral.state.rawValue)) — WiFi still works")
            StatusMenu.shared.bluetooth = "🔵 Bluetooth: không khả dụng"
            return
        }
        let characteristic = CBMutableCharacteristic(
            type: Self.commandUUID, properties: [.write], value: nil, permissions: [.writeable])
        let service = CBMutableService(type: Self.serviceUUID, primary: true)
        service.characteristics = [characteristic]
        peripheral.removeAllServices()
        peripheral.add(service)
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        if let error { return print("❌ BLE service error: \(error)") }
        peripheral.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey: [Self.serviceUUID],
            CBAdvertisementDataLocalNameKey: "VirtualPen",
        ])
    }

    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if let error { return print("❌ BLE advertising error: \(error)") }
        print("🔵 Bluetooth: advertising as \"VirtualPen\"")
        StatusMenu.shared.bluetooth = "🔵 Bluetooth: sẵn sàng (VirtualPen)"
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        for request in requests {
            if let value = request.value { onCommand(String(decoding: value, as: UTF8.self)) }
        }
        if let first = requests.first { peripheral.respond(to: first, withResult: .success) }
    }
}
