# AI Troubleshooting Prompt

You are a Linux audio troubleshooting expert. Help me debug an internal speaker no-sound issue on a Huawei laptop running Ubuntu/Linux. This may not be a PipeWire volume issue; it may be a Conexant SN6140 codec / speaker amplifier wake-up issue.

Known facts or things to verify:

- The machine may be HUAWEI CREF-XX / M1010 / SKU C233 / CREF-XX-PCB.
- The audio controller may be Intel Alder Lake PCH-P HDA, PCI ID `8086:51c8`, Huawei subsystem `19e5:3e5f`.
- The codec may be Conexant SN6140, `Vendor Id: 0x14f11f87`, `Subsystem Id: 0x19e53281`.
- The system may be Ubuntu 26.04. PipeWire/WirePlumber may be running normally, and `wpctl status` may show an analog stereo sink.
- ALSA Master/Speaker/PCM may all be unmuted, but the internal speakers still produce no sound.
- This is a Windows + Ubuntu dual-boot system. Do not modify Windows partitions, EFI, or GRUB default boot entries unless the user explicitly asks.

Please proceed like this:

1. Collect evidence first; do not blindly run random fix scripts:
   - `cat /sys/class/dmi/id/sys_vendor /sys/class/dmi/id/product_name /sys/class/dmi/id/product_version /sys/class/dmi/id/product_sku /sys/class/dmi/id/board_name`
   - `lspci -nnk | grep -iA4 -E 'audio|multimedia'`
   - `aplay -l`
   - `wpctl status`
   - `amixer -c 0 scontents`
   - `sed -n '1,120p' /proc/asound/card0/codec#0`
   - `journalctl -k -b --no-pager | grep -iE 'snd|hda|sof|avs|conexant|SN6140'`
2. If the machine is confirmed as HUAWEI CREF-XX + Conexant SN6140, and the audio stack is healthy but the speakers are silent, test a reversible HDA verb sequence.
3. The important part is not only writing the final target state. After cold boot, the speaker amplifier may need an off-then-on wake sequence:
   - Disable speaker EAPD first.
   - Enable GPIO bit 1 mask/direction.
   - Set GPIO data to `0x0`.
   - Set node 0x16 connect select to `0x0`.
   - Sleep for 0.4 seconds.
   - Set GPIO data to `0x2`.
   - Set node 0x16 connect select to `0x1`.
   - Set node 0x17 EAPD to `0x2`.
4. If manual execution restores sound, install it as a systemd timer: run 20 seconds after boot and repeat several times during the first minute so later audio initialization does not overwrite it.
5. State the scope and risk clearly: this is not a generic Ubuntu no-sound fix. It is for the same or very similar Huawei SN6140 codec routing issue.
6. If the user hears a login melody after the fix, that is usually GNOME event sounds becoming audible again. The fix script should not include playback commands like `paplay`, `aplay`, or `speaker-test`.

Explain what evidence you see at each step, why you are making each decision, and provide a rollback path.
