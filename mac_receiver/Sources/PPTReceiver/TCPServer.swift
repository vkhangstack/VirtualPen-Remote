import Foundation
import Network

/// Line-based TCP server (one ASCII command per line), advertised over Bonjour
/// so the phone finds the Mac without typing an IP.
final class TCPServer {
    static let serviceType = "_pptremote._tcp"

    private let listener: NWListener
    private let onCommand: (String) -> Void

    init(port: UInt16, onCommand: @escaping (String) -> Void) throws {
        let params = NWParameters.tcp
        params.includePeerToPeer = true
        listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)
        listener.service = NWListener.Service(name: Host.current().localizedName ?? "Mac", type: Self.serviceType)
        self.onCommand = onCommand
    }

    func start() {
        listener.stateUpdateHandler = { state in
            switch state {
            case .ready:
                print("📶 WiFi: listening on port \(self.listener.port?.rawValue ?? 0) (Bonjour \(Self.serviceType))")
                StatusMenu.shared.wifi = "📶 WiFi: sẵn sàng"
            case .failed(let error):
                print("❌ WiFi server failed: \(error)")
                StatusMenu.shared.wifi = "❌ WiFi: lỗi"
            default: break
            }
        }
        listener.newConnectionHandler = { [weak self] conn in self?.accept(conn) }
        listener.start(queue: .main)
    }

    private func accept(_ conn: NWConnection) {
        print("📱 WiFi client connected: \(conn.endpoint)")
        conn.start(queue: .main)
        receive(on: conn, buffer: Data())
    }

    private func receive(on conn: NWConnection, buffer: Data) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 512) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            var buffer = buffer
            if let data { buffer.append(data) }

            while let newline = buffer.firstIndex(of: 0x0A) {
                let line = String(decoding: buffer[buffer.startIndex..<newline], as: UTF8.self)
                buffer.removeSubrange(buffer.startIndex...newline)
                self.onCommand(line)
            }
            // Drop garbage from clients that never send a newline.
            if buffer.count > 1024 { buffer.removeAll() }

            if isComplete || error != nil {
                print("👋 WiFi client disconnected: \(conn.endpoint)")
                conn.cancel()
                return
            }
            self.receive(on: conn, buffer: buffer)
        }
    }
}
