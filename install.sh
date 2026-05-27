#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  exec sudo bash "$0" "$@"
fi

if ! command -v hda-verb >/dev/null 2>&1 || ! command -v amixer >/dev/null 2>&1; then
  if command -v apt >/dev/null 2>&1; then
    apt update
    apt install -y alsa-tools alsa-utils
  else
    echo "Please install alsa-tools and alsa-utils first." >&2
    exit 1
  fi
fi

install -m 0755 "$ROOT_DIR/scripts/huawei-sn6140-audio-fix" /usr/local/sbin/huawei-sn6140-audio-fix
install -m 0644 "$ROOT_DIR/systemd/huawei-sn6140-audio-fix.service" /etc/systemd/system/huawei-sn6140-audio-fix.service
install -m 0644 "$ROOT_DIR/systemd/huawei-sn6140-audio-fix.timer" /etc/systemd/system/huawei-sn6140-audio-fix.timer
install -m 0755 "$ROOT_DIR/systemd/huawei-sn6140-audio-fix-sleep" /etc/systemd/system-sleep/huawei-sn6140-audio-fix

systemctl daemon-reload
systemctl disable huawei-sn6140-audio-fix.service >/dev/null 2>&1 || true
systemctl enable --now huawei-sn6140-audio-fix.timer

echo "Running the fix once now..."
systemctl restart huawei-sn6140-audio-fix.service

echo "Installed. Reboot and wait 20-60 seconds after login before testing audio."
