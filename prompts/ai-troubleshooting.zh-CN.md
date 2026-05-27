# 给 AI 的排障 Prompt

你是一位 Linux 音频排障专家。请帮我排查一台华为笔记本在 Ubuntu/Linux 下内置扬声器无声的问题。请注意这可能不是 PipeWire 音量问题，而是 Conexant SN6140 codec/功放唤醒问题。

已知或需要重点确认的信息：

- 机器可能是 HUAWEI CREF-XX / M1010 / SKU C233 / CREF-XX-PCB。
- 声卡可能是 Intel Alder Lake PCH-P HDA，PCI ID `8086:51c8`，Huawei subsystem `19e5:3e5f`。
- codec 可能是 Conexant SN6140，`Vendor Id: 0x14f11f87`，`Subsystem Id: 0x19e53281`。
- 系统可能是 Ubuntu 26.04，PipeWire/WirePlumber 正常运行，`wpctl status` 能看到模拟立体声输出。
- ALSA 的 Master/Speaker/PCM 可能都没有静音，但扬声器仍无声。
- 这是 Windows + Ubuntu 双系统，请不要改 Windows 分区、EFI、GRUB 默认启动项，除非用户明确要求。

请按这个思路处理：

1. 先收集证据，不要直接套脚本：
   - `cat /sys/class/dmi/id/sys_vendor /sys/class/dmi/id/product_name /sys/class/dmi/id/product_version /sys/class/dmi/id/product_sku /sys/class/dmi/id/board_name`
   - `lspci -nnk | grep -iA4 -E 'audio|multimedia'`
   - `aplay -l`
   - `wpctl status`
   - `amixer -c 0 scontents`
   - `sed -n '1,120p' /proc/asound/card0/codec#0`
   - `journalctl -k -b --no-pager | grep -iE 'snd|hda|sof|avs|conexant|SN6140'`
2. 如果确认是 HUAWEI CREF-XX + Conexant SN6140，并且音频栈正常但扬声器无声，优先测试可逆的 HDA verb 序列。
3. 关键点不是只写最终状态，而是冷启动后需要先关再开来唤醒功放：
   - 先关扬声器 EAPD。
   - 启用 GPIO bit 1 的 mask/direction。
   - GPIO data 先写 `0x0`。
   - 0x16 connect select 先写 `0x0`。
   - 等 0.4 秒。
   - GPIO data 写 `0x2`。
   - 0x16 connect select 写 `0x1`。
   - 0x17 EAPD 写 `0x2`。
4. 如果手动执行后有声音，把它做成 systemd timer：开机后延迟 20 秒执行，并在第一分钟内重复几次，避免被后续音频初始化覆盖。
5. 明确说明适用范围和风险：这不是通用 Ubuntu 无声修复，只适用于相同或高度相似的 SN6140/Huawei codec 路由问题。
6. 如果用户听到登录旋律，那通常是 GNOME 系统事件音恢复可听了，不是修复脚本主动播放音频；修复脚本不应包含 `paplay`、`aplay`、`speaker-test` 等播放命令。

请在每一步解释你看到的证据、为什么这么判断，并提供可回滚方案。
