import AppKit

let port: UInt16 = 50555

// Flush logs line by line even when output is redirected to a file.
setvbuf(stdout, nil, _IOLBF, 0)

/// IPv4 addresses of active interfaces, shown so the user can connect manually
/// if Bonjour discovery is blocked on their network.
func localIPv4Addresses() -> [String] {
    var result: [String] = []
    var ifaddr: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return result }
    defer { freeifaddrs(ifaddr) }
    for ptr in sequence(first: first, next: { $0.pointee.ifa_next }) {
        let ifa = ptr.pointee
        guard let addr = ifa.ifa_addr, addr.pointee.sa_family == UInt8(AF_INET),
              (ifa.ifa_flags & UInt32(IFF_LOOPBACK)) == 0 else { continue }
        var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        if getnameinfo(addr, socklen_t(addr.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0 {
            result.append(String(cString: host))
        }
    }
    return result
}

func handle(_ raw: String) {
    let text = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    guard let cmd = Command(rawValue: text) else {
        if !text.isEmpty { print("⚠️  Ignored unknown command: \(text)") }
        return
    }
    print("▶︎ \(cmd.rawValue)")
    StatusMenu.shared.received(cmd)
    KeySender.perform(cmd)
}

let addresses = localIPv4Addresses().map { "\($0):\(port)" }
StatusMenu.shared.addresses = addresses

print("""
=== VirtualPen Receiver ===
Mở app trên điện thoại → chọn Mac này (WiFi) hoặc "VirtualPen" (Bluetooth).
IP thủ công: \(addresses.joined(separator: ", "))

""")

if !KeySender.ensureAccessibility() {
    print("""
    ⚠️  Chưa có quyền Accessibility — phím sẽ không được gửi.
       System Settings → Privacy & Security → Accessibility → bật cho app đang chạy receiver (Terminal, iTerm, VS Code, Xcode…),
       rồi chạy lại.

    """)
}

// Globals keep both transports alive for the life of the process.
let server: TCPServer?
do {
    server = try TCPServer(port: port, onCommand: handle)
    server?.start()
} catch {
    server = nil
    print("❌ Không mở được cổng \(port): \(error)")
    StatusMenu.shared.wifi = "❌ WiFi: cổng \(port) đang bận"
}
let ble = BLEPeripheral(onCommand: handle)

// Run as a menu bar app (no Dock icon). Still logs to stdout when started from a terminal.
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
StatusMenu.shared.install()
withExtendedLifetime((server, ble)) { app.run() }
