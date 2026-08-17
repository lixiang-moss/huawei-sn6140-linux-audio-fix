#!/usr/bin/env bash
set -euo pipefail

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  exec sudo bash "$0" "$@"
fi

systemctl disable --now huawei-sn6140-audio-fix.timer >/dev/null 2>&1 || true
systemctl stop huawei-sn6140-audio-fix.service >/dev/null 2>&1 || true
systemctl stop huawei-sn6140-audio-resume-fix.service >/dev/null 2>&1 || true

rm -f /usr/local/sbin/huawei-sn6140-audio-fix
rm -f /etc/systemd/system/huawei-sn6140-audio-fix.service
rm -f /etc/systemd/system/huawei-sn6140-audio-fix.timer
rm -f /etc/systemd/system/huawei-sn6140-audio-resume-fix.service
rm -f /etc/systemd/system-sleep/huawei-sn6140-audio-fix
rm -f /usr/lib/systemd/system-sleep/huawei-sn6140-audio-fix
rm -f /etc/modprobe.d/huawei-sn6140-audio.conf
rm -f /etc/udev/rules.d/99-huawei-sn6140-audio-power.rules

systemctl daemon-reload
systemctl reset-failed huawei-sn6140-audio-fix.service >/dev/null 2>&1 || true
udevadm control --reload-rules || true

echo "Uninstalled. Reboot to fully restore kernel module and PCI runtime PM defaults."
