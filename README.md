# Huawei CREF-XX / Conexant SN6140 Linux Speaker Fix

[中文 README](README.zh-CN.md)

This repository documents and automates a workaround for a **HUAWEI CREF-XX / M1010** laptop where the internal speakers are silent on Ubuntu/Linux.

This is not a generic "Ubuntu no sound" fix. It targets a specific failure mode: the audio device is detected, PipeWire is running, ALSA mixers are unmuted, but the Conexant SN6140 codec / speaker amplifier does not wake correctly after cold boot.

## Verified Hardware

Verified on:

- Machine: HUAWEI CREF-XX
- Product version: M1010
- SKU: C233
- Board: CREF-XX-PCB
- OS: Ubuntu 26.04 LTS
- Kernel: 7.0.0-15-generic
- Audio controller: Intel Alder Lake PCH-P HDA `8086:51c8`
- PCI subsystem: Huawei `19e5:3e5f`
- Codec: Conexant SN6140
- Codec vendor: `0x14f11f87`
- Codec subsystem: `0x19e53281`

Similar models may also be affected, but verify your hardware first.

## Symptoms

Typical symptoms:

- Internal speakers are completely silent on Ubuntu/Linux.
- Sound works on Windows.
- `wpctl status` shows an internal analog stereo sink.
- `aplay -l` shows `SN6140 Analog`.
- `amixer -c 0 scontents` shows Master, Speaker, and PCM unmuted.
- Playback appears to run, but no sound comes from the speakers.
- A manual HDA verb off-then-on sequence immediately restores sound.

## AI-Assisted Troubleshooting

If you want an AI assistant to debug this machine safely, use one of these prompts:

- Chinese: [prompts/ai-troubleshooting.zh-CN.md](prompts/ai-troubleshooting.zh-CN.md)
- English: [prompts/ai-troubleshooting.en.md](prompts/ai-troubleshooting.en.md)

The prompt tells the AI to collect evidence first, confirm the SN6140/CREF-XX hardware, avoid touching Windows/EFI/GRUB on dual-boot systems, and test a reversible HDA verb sequence instead of treating it as a generic PipeWire volume problem.

## Manual Installation

Install dependencies:

```bash
sudo apt install alsa-tools alsa-utils
```

Install this workaround:

```bash
git clone https://github.com/lixiang-moss/huawei-sn6140-linux-audio-fix.git
cd huawei-sn6140-linux-audio-fix
sudo bash install.sh
```

The installer enables a systemd timer:

```bash
systemctl status huawei-sn6140-audio-fix.timer
```

The timer runs the fix 20 seconds after boot and repeats it several times during the first minute. This avoids the common failure where the codec state is reset by later audio initialization.

## Temporary Manual Test

To test the current session without installing the timer:

```bash
sudo scripts/huawei-sn6140-audio-fix once
```

If this immediately restores speaker output, your issue is likely the same SN6140 cold-boot speaker amplifier wake-up problem.

## Uninstall

```bash
sudo bash uninstall.sh
```

## What It Does

The script does two things:

1. Unmutes ALSA Master/Speaker/PCM.
2. Sends an HDA verb sequence to the SN6140 codec:
   - Disable speaker EAPD first.
   - Enable GPIO bit 1 mask and direction.
   - Set GPIO/route to the off state.
   - Sleep for 0.4 seconds.
   - Set GPIO/route back to the speaker state.
   - Enable speaker EAPD.

The important part is the off-then-on sequence. Writing only the final target state can appear to succeed while the speaker amplifier remains silent after cold boot.

## Notes

- The script does not play startup music. It contains no `paplay`, `aplay`, or `speaker-test` command.
- If you hear a GNOME login melody after fixing audio, it is probably the normal system event sound becoming audible again.
- This workaround does not modify Windows partitions, EFI, or GRUB default boot settings.
- Do not use this on unrelated audio hardware unless you know the HDA verb sequence applies.

## Diagnostic Commands

```bash
cat /sys/class/dmi/id/sys_vendor \
    /sys/class/dmi/id/product_name \
    /sys/class/dmi/id/product_version \
    /sys/class/dmi/id/product_sku \
    /sys/class/dmi/id/board_name

lspci -nnk | grep -iA4 -E 'audio|multimedia'
aplay -l
wpctl status
amixer -c 0 scontents
sed -n '1,120p' /proc/asound/card0/codec#0
journalctl -k -b --no-pager | grep -iE 'snd|hda|sof|avs|conexant|SN6140'
```

## Suggested Titles

Good repository or article titles:

- `huawei-sn6140-linux-audio-fix`
- `Huawei CREF-XX Conexant SN6140 Linux Speaker Fix`
- `Ubuntu 26.04 Huawei CREF-XX No Sound Fix`
- `Fix Huawei MateBook CREF-XX SN6140 Speakers on Linux`

## Publishing Checklist

Create a new standalone GitHub repository with this directory as its root. Do not copy this into an unrelated project repository.
