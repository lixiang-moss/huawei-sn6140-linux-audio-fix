# AI Troubleshooting Prompt

You are a Linux audio troubleshooting expert. Help me debug an internal speaker no-sound issue on a Huawei MateBook 16D running Ubuntu 26.04. The speakers may be silent at boot, stop working after idle, or stop working after lid suspend/resume. This may not be a PipeWire volume issue; it may be a Conexant SN6140 codec / speaker amplifier state-loss issue.

Known facts or things to verify:

- The common model name may be Huawei MateBook 16D.
- Linux DMI may report the machine as HUAWEI CREF-XX / M1010 / SKU C233 / CREF-XX-PCB.
- The audio controller may be Intel Alder Lake PCH-P HDA, PCI ID `8086:51c8`, Huawei subsystem `19e5:3e5f`.
- The codec may be Conexant SN6140, `Vendor Id: 0x14f11f87`, `Subsystem Id: 0x19e53281`.
- The system may be Ubuntu 26.04. PipeWire/WirePlumber may be running normally, and `wpctl status` may show an analog stereo sink.
- ALSA Master/Speaker/PCM may look correct, but the internal speakers still produce no sound.
- Speakers may work after boot, then stop working after idle.
- Speakers may stop working after lid suspend/resume, and plugging in a 3.5 mm headset may make the internal speakers work again.
- This is a Windows + Ubuntu dual-boot system. Do not modify Windows partitions, EFI, or GRUB default boot entries unless the user explicitly asks.

Please proceed like this:

1. Collect evidence first; do not blindly run random fix scripts:
   - `cat /sys/class/dmi/id/sys_vendor /sys/class/dmi/id/product_name /sys/class/dmi/id/product_version /sys/class/dmi/id/product_sku /sys/class/dmi/id/board_name`
   - `lspci -nnk | grep -iA4 -E 'audio|multimedia'`
   - `aplay -l`
   - `wpctl status`
   - `amixer -c 0 scontents`
   - `sed -n '1,160p' /proc/asound/card0/codec#0`
   - `cat /sys/module/snd_hda_intel/parameters/power_save /sys/module/snd_hda_intel/parameters/power_save_controller`
   - `cat /sys/bus/pci/devices/0000:00:1f.3/power/control`
   - `journalctl -k -b --no-pager | grep -iE 'snd|hda|sof|avs|conexant|SN6140|suspend|resume'`
2. If the machine is confirmed as HUAWEI CREF-XX + Conexant SN6140, and the audio stack is healthy but the speakers are silent, test a reversible HDA verb sequence.
3. The important part is not only writing the final target state. The speaker amplifier may need an off-then-on wake sequence:
   - Disable speaker EAPD first.
   - Enable GPIO bit 1 mask/direction.
   - Set GPIO data to `0x0`.
   - Set node 0x16 connect select to `0x0`.
   - Sleep for 0.4 seconds.
   - Set GPIO data to `0x2`.
   - Set node 0x16 connect select to `0x1`.
   - Set node 0x17 EAPD to `0x2`.
4. If speakers stop working after idle, check and disable HDA/PCI runtime power saving:
   - `snd_hda_intel power_save=0`
   - `snd_hda_intel power_save_controller=N`
   - `power/control=on` for the Huawei `8086:51c8 / 19e5:3e5f` PCI audio controller
5. If speakers stop working after lid resume, compare `amixer -c 0 scontents` before and after resume. A common bad state is `Speaker` becoming `0% [off]` while `Headphone` remains `[on]`. Use a delayed, repeated system-sleep `post` fix so ALSA/WirePlumber restore does not overwrite the speaker mixer after the first attempt.
6. State the scope and risk clearly: this is not a generic Ubuntu no-sound fix. It is for the same or very similar Huawei SN6140 codec routing issue.
7. If the user hears a login melody after the fix, that is usually GNOME event sounds becoming audible again. The fix script should not include playback commands like `paplay`, `aplay`, or `speaker-test`.

Explain what evidence you see at each step, why you are making each decision, and provide a rollback path.
