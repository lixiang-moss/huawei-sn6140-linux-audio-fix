# Huawei CREF-XX / Conexant SN6140 Linux Speaker Fix

[中文 README](README.zh-CN.md)

This repository documents and automates a workaround for a **HUAWEI CREF-XX / M1010** laptop where the internal speakers are silent on Ubuntu/Linux, stop working after idle, or stop working after lid suspend/resume.

This is not a generic "Ubuntu no sound" fix. It targets a specific failure mode: the audio device is detected, PipeWire/WirePlumber is running, the output device exists, but the Conexant SN6140 codec / speaker amplifier does not keep the correct state after cold boot, runtime power saving, or suspend/resume.

## Verified Hardware

Verified on:

- Machine: HUAWEI CREF-XX
- Product version: M1010
- SKU: C233
- Board: CREF-XX-PCB
- OS: Ubuntu 26.04 LTS
- Kernels: `7.0.0-15-generic`, `7.0.0-27-generic`
- Audio controller: Intel Alder Lake PCH-P HDA `8086:51c8`
- PCI subsystem: Huawei `19e5:3e5f`
- Codec: Conexant SN6140
- Codec vendor: `0x14f11f87`
- Codec subsystem: `0x19e53281`

Similar models may also be affected, but verify your hardware first.

## Symptoms Covered

Typical symptoms:

- Internal speakers are completely silent on Ubuntu/Linux.
- Sound works on Windows.
- `wpctl status` shows an internal analog stereo sink.
- `aplay -l` shows `SN6140 Analog`.
- Playback appears to run, but no sound comes from the speakers.
- A manual HDA verb off-then-on sequence immediately restores sound.
- Speakers work after boot, then stop working after idle.
- Speakers stop working after closing the lid, suspending, and resuming.
- Plugging a 3.5 mm headset can make the internal speakers work again.

## Root Cause

This project originally fixed a cold-boot issue where the SN6140 speaker amplifier was not woken correctly. Later testing on Ubuntu 26.04 / kernel `7.0.0-27-generic` exposed two related variants:

1. HDA runtime power saving in `snd_hda_intel` can let the codec / amplifier lose state after idle.
2. After suspend/resume, ALSA/WirePlumber restore ordering can set the `Speaker` mixer back to `0% [off]`. Plugging in a headset triggers a jack event and refreshes routing, so speakers start working again.

The final workaround handles cold boot, runtime power saving, and lid suspend/resume together.

## AI-Assisted Troubleshooting

If you want an AI assistant to debug this machine safely, use one of these prompts:

- Chinese: [prompts/ai-troubleshooting.zh-CN.md](prompts/ai-troubleshooting.zh-CN.md)
- English: [prompts/ai-troubleshooting.en.md](prompts/ai-troubleshooting.en.md)

The prompt tells the AI to collect evidence first, confirm the SN6140/CREF-XX hardware, avoid touching Windows/EFI/GRUB on dual-boot systems, and test a reversible HDA verb sequence instead of treating it as a generic PipeWire volume problem.

## Installation

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

Reboot once after installation:

```bash
sudo reboot
```

The installer enables a systemd timer:

```bash
systemctl status huawei-sn6140-audio-fix.timer
```

It also installs a suspend/resume hook:

```bash
ls -l /etc/systemd/system-sleep/huawei-sn6140-audio-fix
```

## Status Check

```bash
/usr/local/sbin/huawei-sn6140-audio-fix status
```

Expected key values:

```text
/sys/module/snd_hda_intel/parameters/power_save=0
/sys/module/snd_hda_intel/parameters/power_save_controller=N
/sys/bus/pci/devices/0000:00:1f.3/power/control=on
```

After a failed lid resume, the common bad state is:

```text
Speaker: Playback 0 [0%] [-74.00dB] [off]
```

Running the fix once should restore it:

```bash
sudo /usr/local/sbin/huawei-sn6140-audio-fix once
```

## What It Does

The installer and script do four things:

1. Confirm that the machine exposes the Conexant SN6140 codec.
2. Unmute ALSA Master/Speaker/PCM and disable `Auto-Mute Mode`.
3. Disable HDA/PCI audio runtime power saving:

```text
options snd_hda_intel power_save=0 power_save_controller=N
```

It also installs a udev rule that pins PCI runtime PM to `on` for the Huawei `8086:51c8 / 19e5:3e5f` audio controller.

4. Sends an HDA verb sequence to the SN6140 codec:
   - Disable speaker EAPD first.
   - Enable GPIO bit 1 mask and direction.
   - Set GPIO/route to the off state.
   - Sleep for 0.4 seconds.
   - Set GPIO/route back to the speaker state.
   - Enable speaker EAPD.

The important part is the off-then-on sequence. Writing only the final target state can appear to succeed while the speaker amplifier remains silent after cold boot or resume.

## Boot and Resume Strategy

- A systemd timer starts 20 seconds after boot and repeats the fix 12 times over about 2 minutes.
- A system-sleep hook schedules a delayed transient unit after lid suspend/resume.
- The delayed resume fix waits briefly, then repeats several times to cover the window where ALSA/WirePlumber/desktop session restore may overwrite the speaker mixer.

## Uninstall

```bash
sudo bash uninstall.sh
sudo reboot
```

Uninstall removes the script, systemd timer, system-sleep hook, modprobe config, and udev rule. Reboot to fully restore kernel module parameters and PCI runtime PM defaults.

## Notes

- The script does not play startup music. It contains no `paplay`, `aplay`, or `speaker-test` command.
- If you hear a GNOME login melody after fixing audio, it is probably the normal system event sound becoming audible again.
- This workaround does not modify Windows partitions, EFI, or GRUB default boot settings.
- Disabling HDA audio power saving may slightly increase idle power usage, but it is usually preferable to losing speaker output.
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
sed -n '1,160p' /proc/asound/card0/codec#0
journalctl -k -b --no-pager | grep -iE 'snd|hda|sof|avs|conexant|SN6140|suspend|resume'
journalctl -b --no-pager | grep -iE 'huawei-sn6140|suspend|resume|speaker'
```
