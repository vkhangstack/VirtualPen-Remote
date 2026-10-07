// VirtualPen Receiver for Linux and Windows: receives clicker commands from the
// phone app over WiFi (TCP + mDNS) or Bluetooth LE and turns them into keystrokes.
// The macOS counterpart lives in mac_receiver.
package main

import (
	"bufio"
	"flag"
	"fmt"
	"log"
	"net"
	"os"
	"os/signal"
	"strings"
	"syscall"

	"github.com/grandcat/zeroconf"
)

const (
	port        = 50555
	serviceType = "_pptremote._tcp"
)

type keySender interface {
	Press(Command) error
	Close()
}

func main() {
	noBLE := flag.Bool("no-ble", false, "tắt Bluetooth, chỉ dùng WiFi")
	flag.Parse()
	log.SetFlags(log.Ltime)

	fmt.Printf(`=== VirtualPen Receiver ===
Mở app trên điện thoại → chọn máy tính này (WiFi) hoặc "VirtualPen" (Bluetooth).
IP thủ công: %s

`, strings.Join(localIPv4Addresses(), ", "))

	keys, err := newKeySender()
	if err != nil {
		fmt.Printf("⚠️  Không gửi phím được: %v\n\n", err)
	} else {
		defer keys.Close()
	}

	handle := func(raw string) {
		cmd, ok := parseCommand(raw)
		if !ok {
			if t := strings.TrimSpace(raw); t != "" {
				log.Printf("⚠️  Ignored unknown command: %s", t)
			}
			return
		}
		log.Printf("▶︎ %s", cmd)
		if keys == nil {
			return
		}
		if err := keys.Press(cmd); err != nil {
			log.Printf("❌ %v", err)
		}
	}

	listener, err := net.Listen("tcp", fmt.Sprintf(":%d", port))
	if err != nil {
		log.Fatalf("❌ Không mở được cổng %d: %v", port, err)
	}
	go serveTCP(listener, handle)
	log.Printf("📶 WiFi: listening on port %d", port)

	host, _ := os.Hostname()
	if mdns, err := zeroconf.Register(host, serviceType, "local.", port, nil, nil); err != nil {
		log.Printf("⚠️  Bonjour/mDNS lỗi (%v) — dùng IP thủ công", err)
	} else {
		defer mdns.Shutdown()
		log.Printf("📶 mDNS: advertising %q (%s)", host, serviceType)
	}

	if *noBLE {
		log.Printf("🔵 Bluetooth: tắt (--no-ble)")
	} else if err := startBLE(handle); err != nil {
		log.Printf("🔵 Bluetooth unavailable (%v) — WiFi still works", err)
	} else {
		log.Printf("🔵 Bluetooth: advertising as \"VirtualPen\"")
	}

	stop := make(chan os.Signal, 1)
	signal.Notify(stop, os.Interrupt, syscall.SIGTERM)
	<-stop
	fmt.Println("\nBye!")
}

func serveTCP(listener net.Listener, handle func(string)) {
	for {
		conn, err := listener.Accept()
		if err != nil {
			log.Printf("❌ WiFi accept: %v", err)
			continue
		}
		go func() {
			defer conn.Close()
			log.Printf("📱 WiFi client connected: %s", conn.RemoteAddr())
			scanner := bufio.NewScanner(conn)
			scanner.Buffer(make([]byte, 512), 1024) // drop clients that never send a newline
			for scanner.Scan() {
				handle(scanner.Text())
			}
			log.Printf("👋 WiFi client disconnected: %s", conn.RemoteAddr())
		}()
	}
}

// localIPv4Addresses lists non-loopback IPv4 addresses so the user can connect
// manually if mDNS is blocked on their network.
func localIPv4Addresses() []string {
	var result []string
	addrs, _ := net.InterfaceAddrs()
	for _, a := range addrs {
		if ip, ok := a.(*net.IPNet); ok && !ip.IP.IsLoopback() && ip.IP.To4() != nil {
			result = append(result, fmt.Sprintf("%s:%d", ip.IP, port))
		}
	}
	return result
}
