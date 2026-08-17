#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_NAME="huawei-sn6140-audio-fix"
RESUME_SERVICE_NAME="huawei-sn6140-audio-resume-fix"

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  exec sudo bash "$0" "$@"
fi

need_cmd() {
  command -v "$1" >/dev/null 2>&1
}

install_deps() {
  if need_cmd hda-verb && need_cmd amixer; then
    return
  fi

  if need_cmd apt; then
    apt update
    apt install -y alsa-tools alsa-utils
  else
    echo "Please install alsa-tools and alsa-utils first." >&2
    exit 1
  fi
}

find_sn6140_codec() {
  local f
  shopt -s nullglob
  for f in /proc/asound/card*/codec#*; do
    if grep -q "Codec: Conexant SN6140" "$f" \
      && grep -q "Vendor Id: 0x14f11f87" "$f" \
      && grep -q "Subsystem Id: 0x19e53281" "$f"; then
      echo "$f"
      return 0
    fi
  done
  return 1
}

check_hardware() {
  local codec_path
  if ! codec_path="$(find_sn6140_codec)"; then
    echo "This machine does not expose the tested Huawei CREF-XX / Conexant SN6140 codec." >&2
    echo "Set ALLOW_UNTESTED=1 only if you know your hardware needs this exact HDA verb sequence." >&2
    if [[ "${ALLOW_UNTESTED:-0}" != "1" ]]; then
      exit 1
    fi
  fi

  echo "Detected codec: ${codec_path:-untested override}"
  if [[ -r /sys/class/dmi/id/sys_vendor ]]; then
    echo "DMI:"
    paste -sd ' / ' \
      /sys/class/dmi/id/sys_vendor \
      /sys/class/dmi/id/product_name \
      /sys/class/dmi/id/product_version \
      /sys/class/dmi/id/product_sku \
      /sys/class/dmi/id/board_name 2>/dev/null || true
  fi
}

install_deps
check_hardware

install -m 0755 "$ROOT_DIR/scripts/huawei-sn6140-audio-fix" "/usr/local/sbin/$SCRIPT_NAME"
install -m 0644 "$ROOT_DIR/systemd/huawei-sn6140-audio-fix.service" "/etc/systemd/system/$SCRIPT_NAME.service"
install -m 0644 "$ROOT_DIR/systemd/huawei-sn6140-audio-fix.timer" "/etc/systemd/system/$SCRIPT_NAME.timer"
install -m 0644 "$ROOT_DIR/systemd/huawei-sn6140-audio-resume-fix.service" "/etc/systemd/system/$RESUME_SERVICE_NAME.service"
install -d -m 0755 /usr/lib/systemd/system-sleep
install -m 0755 "$ROOT_DIR/systemd/huawei-sn6140-audio-fix-sleep" "/usr/lib/systemd/system-sleep/$SCRIPT_NAME"
# Older versions used this unsupported location on Ubuntu 26.04.
rm -f "/etc/systemd/system-sleep/$SCRIPT_NAME"
install -m 0644 "$ROOT_DIR/modprobe.d/huawei-sn6140-audio.conf" /etc/modprobe.d/huawei-sn6140-audio.conf
install -m 0644 "$ROOT_DIR/udev/99-huawei-sn6140-audio-power.rules" /etc/udev/rules.d/99-huawei-sn6140-audio-power.rules

systemctl daemon-reload
systemctl disable huawei-sn6140-audio-fix.service >/dev/null 2>&1 || true
systemctl stop "$RESUME_SERVICE_NAME.service" >/dev/null 2>&1 || true
systemctl enable --now huawei-sn6140-audio-fix.timer
systemctl restart huawei-sn6140-audio-fix.timer

udevadm control --reload-rules || true
udevadm trigger --subsystem-match=pci --action=change || true

# Disable an older one-off unit name used during early troubleshooting. It can
# fail at boot and race the maintained fix on the same machine.
if systemctl list-unit-files huawei-audio-fix.service >/dev/null 2>&1; then
  systemctl disable --now huawei-audio-fix.service >/dev/null 2>&1 || true
  systemctl reset-failed huawei-audio-fix.service >/dev/null 2>&1 || true
fi

echo "Running the fix once now..."
"/usr/local/sbin/$SCRIPT_NAME" once
"/usr/local/sbin/$SCRIPT_NAME" status || true

echo
echo "Installed. Reboot once, then test speakers after boot, after idle, and after lid suspend/resume."
