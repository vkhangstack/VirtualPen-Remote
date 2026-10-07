import AppKit
import ApplicationServices

/// Menu bar icon showing connection status, so the receiver is usable as a
/// double-clickable app without a terminal window.
final class StatusMenu: NSObject {
    static let shared = StatusMenu()

    var wifi = "📶 WiFi: đang khởi động…" { didSet { rebuild() } }
    var bluetooth = "🔵 Bluetooth: đang khởi động…" { didSet { rebuild() } }
    var lastCommand = "Chưa nhận lệnh nào" { didSet { rebuild() } }
    var addresses: [String] = [] { didSet { rebuild() } }

    private var statusItem: NSStatusItem?
    private let timeFormat: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    func install() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "play.rectangle", accessibilityDescription: "VirtualPen Receiver")
        statusItem = item
        rebuild()
    }

    func received(_ cmd: Command) {
        lastCommand = "▶︎ \(cmd.rawValue) lúc \(timeFormat.string(from: Date()))"
    }

    private func rebuild() {
        guard let statusItem else { return }
        let menu = NSMenu()
        menu.addItem(info("VirtualPen Receiver"))
        menu.addItem(.separator())
        menu.addItem(info(wifi))
        for address in addresses { menu.addItem(info("    IP: \(address)")) }
        menu.addItem(info(bluetooth))
        menu.addItem(info(lastCommand))
        menu.addItem(.separator())
        if AXIsProcessTrusted() {
            menu.addItem(info("✅ Đã có quyền Accessibility"))
        } else {
            menu.addItem(action("⚠️ Cấp quyền Accessibility…", #selector(openAccessibilitySettings)))
        }
        menu.addItem(action("Thoát", #selector(quit), key: "q"))
        statusItem.menu = menu
    }

    private func info(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func action(_ title: String, _ selector: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: key)
        item.target = self
        return item
    }

    @objc private func openAccessibilitySettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
