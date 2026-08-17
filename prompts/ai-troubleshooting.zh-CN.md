# 给 AI 的排障 Prompt

你是一位 Linux 音频排障专家。请帮我排查一台华为 MateBook 16D 在 Ubuntu 26.04 下内置扬声器无声、空闲后无声、或合盖唤醒后无声的问题。请注意这可能不是 PipeWire 音量问题，而是 Conexant SN6140 codec/功放状态丢失问题。

已知或需要重点确认的信息：

- 常见机型名可能是华为 MateBook 16D。
- Linux DMI 信息可能显示为 HUAWEI CREF-XX / M1010 / SKU C233 / CREF-XX-PCB。
- 声卡可能是 Intel Alder Lake PCH-P HDA，PCI ID `8086:51c8`，Huawei subsystem `19e5:3e5f`。
- codec 可能是 Conexant SN6140，`Vendor Id: 0x14f11f87`，`Subsystem Id: 0x19e53281`。
- 系统可能是 Ubuntu 26.04，PipeWire/WirePlumber 正常运行，`wpctl status` 能看到模拟立体声输出。
- 已复现的内核包括 `7.0.0-15-generic`、`7.0.0-27-generic` 和 `7.0.0-29-generic`。
- ALSA 的 Master/Speaker/PCM 可能看起来正常，但扬声器仍无声。
- 可能出现“开机后有声音，过一会没声音”。
- 可能出现“合盖 suspend 后再打开没声音，插入 3.5mm 耳机后外放反而恢复”。
- 这是 Windows + Ubuntu 双系统，请不要改 Windows 分区、EFI、GRUB 默认启动项，除非用户明确要求。

请按这个思路处理：

1. 先收集证据，不要直接套脚本：
   - `cat /sys/class/dmi/id/sys_vendor /sys/class/dmi/id/product_name /sys/class/dmi/id/product_version /sys/class/dmi/id/product_sku /sys/class/dmi/id/board_name`
   - `lspci -nnk | grep -iA4 -E 'audio|multimedia'`
   - `aplay -l`
   - `wpctl status`
   - `amixer -c 0 scontents`
   - `sed -n '1,160p' /proc/asound/card0/codec#0`
   - `cat /sys/module/snd_hda_intel/parameters/power_save /sys/module/snd_hda_intel/parameters/power_save_controller`
   - `cat /sys/bus/pci/devices/0000:00:1f.3/power/control`
   - `journalctl -k -b --no-pager | grep -iE 'snd|hda|sof|avs|conexant|SN6140|suspend|resume'`
   - `journalctl -b --no-pager | grep -iE 'huawei-sn6140|systemd-sleep|suspend|resume'`
   - `ls -l /usr/lib/systemd/system-sleep/huawei-sn6140-audio-fix /etc/systemd/system-sleep/huawei-sn6140-audio-fix 2>&1`
   - `systemctl status huawei-sn6140-audio-resume-fix.service --no-pager`
2. 如果确认是 HUAWEI CREF-XX + Conexant SN6140，并且音频栈正常但扬声器无声，优先测试可逆的 HDA verb 序列。
3. 关键点不是只写最终状态，而是需要先关再开来唤醒功放：
   - 先关扬声器 EAPD。
   - 启用 GPIO bit 1 的 mask/direction。
   - GPIO data 先写 `0x0`。
   - 0x16 connect select 先写 `0x0`。
   - 等 0.4 秒。
   - GPIO data 写 `0x2`。
   - 0x16 connect select 写 `0x1`。
   - 0x17 EAPD 写 `0x2`。
4. 如果“空闲一段时间后没声音”，检查并关闭 HDA/PCI runtime power saving：
   - `snd_hda_intel power_save=0`
   - `snd_hda_intel power_save_controller=N`
   - Huawei `8086:51c8 / 19e5:3e5f` PCI audio controller 的 `power/control=on`
5. 如果“合盖唤醒后没声音”，不要只看 mixer：
   - 某些失败中 `Speaker` 会变成 `0% [off]`；但长时间 suspend 后也可能仍显示 `100% [on]`，codec 为 D0、EAPD 为 `0x2`、GPIO data 为 1，外置功放却实际没有响应。
   - 插耳机后外放恢复，说明 jack 状态边沿重新初始化了路由/功放，不能据此判断耳机和扬声器端口接反。
   - Ubuntu 26.04 的 systemd 执行 `/usr/lib/systemd/system-sleep/` 中的钩子。不要把有效钩子只安装到 `/etc/systemd/system-sleep/`。
   - `post` 钩子应快速启动独立的 root systemd 服务；服务稍作延迟后重复执行修复，覆盖设备和桌面音频栈恢复的时间窗口。
   - 用 `journalctl -b -t huawei-sn6140-audio-sleep` 和 `journalctl -b -u huawei-sn6140-audio-resume-fix.service` 证明钩子和服务真的运行，不能只凭一次短时间合盖后碰巧有声就判定修复成功。
6. 执行 `hda-verb` 必须有 root 权限。不要吞掉关键命令的错误；如果 codec、hwdep 设备或 HDA verb 写入失败，脚本和 systemd 服务必须返回非零状态。
7. 明确说明适用范围和风险：这不是通用 Ubuntu 无声修复，只适用于相同或高度相似的 SN6140/Huawei codec 路由问题。
8. 如果用户听到登录旋律，那通常是 GNOME 系统事件音恢复可听了，不是修复脚本主动播放音频；修复脚本不应包含 `paplay`、`aplay`、`speaker-test` 等播放命令。

请在每一步解释你看到的证据、为什么这么判断，并提供可回滚方案。
