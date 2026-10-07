# VirtualPen Remote — bút trình chiếu bằng điện thoại

Biến điện thoại (iOS/Android) thành bút trình chiếu để điều khiển PowerPoint (Keynote, LibreOffice Impress) trên **macOS, Windows và Linux** qua **WiFi** hoặc **Bluetooth**.

```
┌──────────────────┐   WiFi: TCP :50555 (Bonjour _pptremote._tcp)   ┌────────────────────────┐   phím ảo   ┌────────────┐
│ mobile_app       │ ─────────────────────────────────────────────▶ │ mac_receiver (Swift)   │ ──────────▶ │ PowerPoint │
│ (Flutter)        │   Bluetooth LE: ghi vào GATT characteristic    │ desktop_receiver (Go)  │             │ / Keynote  │
└──────────────────┘                                                │   Windows · Linux      │             │ / Impress  │
                                                                    └────────────────────────┘             └────────────┘
```

Điện thoại không thể tự điều khiển PowerPoint, nên máy tính cần chạy một receiver nhỏ (macOS: `mac_receiver`, Windows/Linux: `desktop_receiver`). Receiver nhận lệnh rồi giả lập phím bấm, giống như một chiếc bút trình chiếu USB thật.

## Đặc tả

### Chức năng

| Nút trên app               | Lệnh     | macOS | Windows / Linux |
|----------------------------|----------|-------|-----------------|
| TIẾP (nút lớn / vuốt trái) | `NEXT`   | →     | →               |
| LÙI (vuốt phải)            | `PREV`   | ←     | ←               |
| Từ đầu                     | `START`  | ⌘⇧↩   | F5              |
| Slide này                  | `RESUME` | ⌘↩    | Shift+F5        |
| Màn đen                    | `BLACK`  | B (bấm lại để tắt) | B      |
| Kết thúc                   | `END`    | Esc   | Esc             |
| *(không có nút)*           | `WHITE`  | W     | W               |

Trên macOS, receiver tự đưa PowerPoint/Keynote lên phía trước trước mỗi lệnh. Trên Windows/Linux, phím được gửi tới cửa sổ đang ở phía trước, nên hãy giữ cửa sổ trình chiếu ở phía trước.

Ngoài ra: rung phản hồi khi bấm, giữ màn hình luôn sáng khi đang điều khiển, tự quay về màn kết nối khi mất kết nối.

### Kết nối

- **WiFi (khuyên dùng, độ trễ thấp nhất):** receiver quảng bá dịch vụ Bonjour/mDNS `_pptremote._tcp` trên cổng TCP `50555`; app tự tìm thấy, chỉ cần chạm để kết nối. Nếu mạng chặn Bonjour (WiFi công ty/khách sạn), bấm **Nhập IP thủ công** và dùng IP mà receiver in ra.
- **Bluetooth LE (khi không có WiFi chung):** receiver làm BLE peripheral tên `VirtualPen`.
  - Service `7A1C0001-5B8E-4C3A-9F2D-1E6B8A4C0D01`
  - Characteristic `7A1C0002-5B8E-4C3A-9F2D-1E6B8A4C0D01` (write)

### Giao thức

Lệnh là chuỗi ASCII (danh sách ở bảng trên). Qua WiFi mỗi lệnh kết thúc bằng `\n`; qua BLE mỗi lần ghi là một lệnh. Receiver chỉ chấp nhận các lệnh trong danh sách trắng và bỏ qua mọi thứ khác, nên client không thể gửi phím tuỳ ý.

> Không có xác thực: bất kỳ ai cùng mạng WiFi (hoặc trong tầm Bluetooth) đều có thể chuyển slide khi receiver đang chạy. Tắt receiver khi không trình chiếu.

## Cài đặt & sử dụng

### 1. Mac receiver

**Cách nhanh — cài từ DMG:** mở `release/VirtualPenReceiver-<ver>.dmg`, kéo **VirtualPen Receiver** vào **Applications**, rồi mở app. App chạy trên thanh menu (biểu tượng ▶︎ hình chữ nhật, không có icon ở Dock). Bấm vào biểu tượng đó để xem trạng thái WiFi/Bluetooth, IP và lệnh vừa nhận; cũng có nút cấp quyền và nút **Thoát**.

- Lần đầu mở, macOS có thể chặn vì app chưa notarize: chuột phải vào app → **Open** → **Open** (hoặc chạy `xattr -dr com.apple.quarantine "/Applications/VirtualPen Receiver.app"`).
- Cấp quyền **Accessibility** cho **VirtualPen Receiver** (menu ▶︎ → *Cấp quyền Accessibility…*), rồi Thoát và mở lại app.
- Mỗi lần build lại app (chữ ký ad-hoc thay đổi), có thể phải tắt rồi bật lại quyền này.

**Chạy từ mã nguồn:**

```bash
cd mac_receiver
swift build -c release
.build/release/PPTReceiver
```

Lần chạy đầu:
1. **Accessibility** (bắt buộc để gửi phím): System Settings → Privacy & Security → Accessibility → bật cho app đang chạy receiver (**Terminal**, iTerm, **Visual Studio Code**, Xcode…), rồi chạy lại receiver.
2. **Bluetooth**: bấm *Allow* khi macOS hỏi.

Receiver in ra IP và trạng thái WiFi/Bluetooth, sau đó log từng lệnh nhận được.

### 1b. Windows receiver

1. Giải nén `release/VirtualPenReceiver-<ver>-windows-amd64.zip` (máy Snapdragon/ARM dùng bản `-arm64`).
2. Chạy `VirtualPenReceiver.exe`. Một cửa sổ console sẽ mở ra, hiện IP và log từng lệnh; đóng cửa sổ hoặc nhấn Ctrl+C để tắt.
   - SmartScreen có thể cảnh báo vì file chưa ký: bấm **More info → Run anyway**.
   - Khi Windows Firewall hỏi, cho phép trên **Private networks**.
3. Bluetooth cần Windows 10 1803+ và adapter hỗ trợ chế độ peripheral. Nếu không có, WiFi vẫn hoạt động.

Lưu ý: Windows không cho gửi phím vào app chạy bằng quyền Administrator từ một tiến trình thường. Hãy chạy PowerPoint bình thường (không "Run as administrator").

### 1c. Linux receiver

```bash
tar xzf VirtualPenReceiver-<ver>-linux-amd64.tar.gz     # hoặc -arm64
cd VirtualPenReceiver-<ver>-linux-amd64
./install-linux.sh        # một lần: cấp quyền /dev/uinput cho user (cần sudo), rồi đăng xuất/đăng nhập lại
./virtualpen-receiver     # thêm --no-ble nếu không muốn dùng Bluetooth
```

- Phím được gửi qua **uinput** (bàn phím ảo của kernel), nên chạy được trên cả **X11 lẫn Wayland**. Dùng được với LibreOffice Impress, cũng như PowerPoint/Google Slides trên trình duyệt.
- Bluetooth dùng BlueZ (`bluetoothd` phải đang chạy).
- Nếu có tường lửa: mở `50555/tcp` và `5353/udp` (mDNS), ví dụ `sudo ufw allow 50555/tcp && sudo ufw allow 5353/udp`.

### 2. App điện thoại

```bash
cd mobile_app
flutter run            # cắm điện thoại vào, hoặc:
flutter build apk      # Android
flutter build ios      # iOS (cần ký bằng Xcode)
```

Lần đầu mở app, cho phép **Bluetooth** và **Mạng cục bộ** (iOS).

### 3. Trình chiếu

1. Mở file trình chiếu trên máy tính.
2. Mở app → chạm vào tên máy tính (biểu tượng WiFi hoặc Bluetooth).
3. Bấm **Từ đầu** để bắt đầu trình chiếu, sau đó bấm **TIẾP** hoặc vuốt để chuyển slide.

## Build bản release

```bash
./build.sh              # build tất cả: mac + linux + windows + android + ios (mặc định)
./build.sh mac          # chỉ Mac receiver
./build.sh linux windows  # chỉ receiver Linux + Windows (cần Go, cross-compile từ Mac)
./build.sh android      # chỉ APK
./build.sh ios          # chỉ IPA
```

Nếu một target lỗi (ví dụ APK), script vẫn build tiếp các target còn lại, cuối cùng in danh sách `✓ OK` / `✗ FAILED` và thoát với mã lỗi 1.

Kết quả nằm trong `release/`:

| File | Nội dung |
|------|----------|
| `VirtualPenReceiver-<ver>.dmg`       | `VirtualPen Receiver.app` (menu bar, universal Apple Silicon + Intel, ad-hoc sign) |
| `VirtualPenReceiver-<ver>-windows-{amd64,arm64}.zip` | `VirtualPenReceiver.exe` |
| `VirtualPenReceiver-<ver>-linux-{amd64,arm64}.tar.gz` | `virtualpen-receiver` + `install-linux.sh` |
| `VirtualPenRemote-<ver>-arm64.apk`   | Android 64-bit (hầu hết điện thoại hiện nay) |
| `VirtualPenRemote-<ver>-armv7.apk`   | Android 32-bit (máy cũ) |
| `VirtualPenRemote-<ver>.ipa`  | iOS production (khi build `ios`) |

Mọi bản build đều là bản release. IPA mặc định xuất kiểu `development` (dùng được với Apple ID miễn phí, chỉ cài trên iPhone đã đăng ký, hết hạn sau 7 ngày). Để đưa lên App Store/TestFlight (cần tài khoản Apple Developer trả phí): `IOS_EXPORT=app-store ./build.sh`.

Phiên bản lấy từ `version:` trong `mobile_app/pubspec.yaml`. APK đang được ký bằng debug key của Flutter, đủ để cài trực tiếp; muốn đưa lên Google Play thì cần cấu hình keystore riêng.

## Cấu trúc

```
mac_receiver/
  Package.swift              Swift package; nhúng Info.plist (quyền Bluetooth) vào binary
  Info.plist                 Dùng cho cả binary lẫn VirtualPen Receiver.app
  Sources/PPTReceiver/
    main.swift               Khởi động, in IP, xử lý lệnh, chạy app menu bar
    StatusMenu.swift         Biểu tượng trên thanh menu: trạng thái, IP, Thoát
    KeySender.swift          Danh sách lệnh → phím (CGEvent)
    TCPServer.swift          Server TCP + quảng bá Bonjour (Network.framework)
    BLEPeripheral.swift      BLE GATT peripheral (CoreBluetooth)
desktop_receiver/            Receiver cho Windows + Linux (Go, không cần cgo)
  main.go                    Khởi động, in IP, server TCP, quảng bá mDNS
  commands.go                Danh sách lệnh hợp lệ (whitelist)
  keys_windows.go            Lệnh → phím (SendInput)
  keys_linux.go              Lệnh → phím (uinput, chạy cả X11 lẫn Wayland)
  ble.go                     BLE GATT peripheral (BlueZ / WinRT)
  install-linux.sh           Cấp quyền /dev/uinput một lần
mobile_app/lib/
  main.dart                  App + theme
  protocol.dart              Lệnh, cổng, UUID (đồng bộ với receiver)
  connection.dart            WifiConnection / BleConnection
  connect_screen.dart        Tự tìm máy tính (Bonjour + BLE scan), nhập IP thủ công
  remote_screen.dart         Giao diện bút trình chiếu
```

## Ghi chú

- macOS: mỗi lệnh đều tự đưa PowerPoint (hoặc Keynote nếu không mở PowerPoint) lên phía trước rồi mới gửi phím.
- macOS: quyền Accessibility gắn với **app khởi chạy receiver**: chạy trong terminal của VS Code thì phải cấp cho *Visual Studio Code*, chạy bằng Xcode thì cấp cho *Xcode*.
- Bluetooth dùng `flutter_blue_plus` với `License.nonprofit` (miễn phí cho cá nhân/phi lợi nhuận). Nếu dùng cho mục đích thương mại, xem điều khoản giấy phép của package.
