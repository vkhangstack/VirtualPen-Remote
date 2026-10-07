#!/usr/bin/env bash
# One-time setup so VirtualPen Receiver can send keystrokes without sudo:
# loads the uinput module at boot and gives the "input" group access to /dev/uinput.
set -euo pipefail

echo uinput | sudo tee /etc/modules-load.d/virtualpen.conf >/dev/null
sudo modprobe uinput
echo 'KERNEL=="uinput", GROUP="input", MODE="0660", OPTIONS+="static_node=uinput"' \
  | sudo tee /etc/udev/rules.d/60-virtualpen-uinput.rules >/dev/null
sudo udevadm control --reload-rules
sudo udevadm trigger --name-match=uinput
sudo usermod -aG input "$USER"

echo "Xong. Đăng xuất rồi đăng nhập lại (để nhóm 'input' có hiệu lực), sau đó chạy ./virtualpen-receiver"
