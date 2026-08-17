# 华为 MateBook 16D / CREF-XX / Conexant SN6140 Ubuntu 26.04 内置扬声器修复

[English README](README.md)

这是一个针对 **华为 MateBook 16D** 笔记本在 **Ubuntu 26.04** 下内置扬声器无声、开机后过一会无声、合盖唤醒后无声的问题记录和修复脚本。该机型在 Linux DMI 信息中显示为 **HUAWEI CREF-XX / M1010 / C233 / CREF-XX-PCB**。

当前默认安装方案为 **v4**，修正了旧版休眠恢复钩子未被 systemd 执行的问题。

它不是通用的 “Ubuntu 没声音” 修复。这个方案针对的是：系统已经识别声卡，PipeWire/WirePlumber 正常，输出设备存在，但 Conexant SN6140 codec / 扬声器功放在冷启动、运行时省电或 suspend/resume 后没有保持正确状态。

## 已验证环境

已在以下环境验证：

- 常见机型名：华为 MateBook 16D
- 机器：HUAWEI CREF-XX
- 产品版本：M1010
- SKU：C233
- 主板：CREF-XX-PCB
- 系统：Ubuntu 26.04 LTS
- 内核：`7.0.0-15-generic`、`7.0.0-27-generic`、`7.0.0-29-generic`
- 音频控制器：Intel Alder Lake PCH-P HDA `8086:51c8`
- PCI subsystem：Huawei `19e5:3e5f`
- Codec：Conexant SN6140
- Codec vendor：`0x14f11f87`
- Codec subsystem：`0x19e53281`

相近机型也可能适用，但请先确认硬件信息。

## 已覆盖症状

典型症状：

- Ubuntu/Linux 下内置扬声器完全无声。
- Windows 下声音正常。
- `wpctl status` 能看到内置模拟立体声输出。
- `aplay -l` 能看到 `SN6140 Analog`。
- 播放测试音时软件链路看起来正常，但扬声器不响。
- 手动执行 HDA verb “先关再开”序列后立刻有声音。
- 开机后起初有声音，但空闲一段时间后无声。
- 合上笔记本进入 suspend，再打开后外放无声。
- 插入 3.5mm 耳机后，外放反而恢复正常。

## 根因判断

这个仓库最初解决的是冷启动后 SN6140 扬声器功放没有被正确唤醒的问题。后来在 Ubuntu 26.04 / kernel `7.0.0-27-generic` 和 `7.0.0-29-generic` 上又复现了两个变体：

1. `snd_hda_intel` 的 HDA runtime power saving 会让 codec/功放在空闲后丢状态。
2. 长时间 suspend 后 SN6140 的外置扬声器功放会丢失硬件锁存状态。此时 codec、PipeWire、`Speaker` mixer 和软件音量都可能显示正常，但功放实际没有工作；插入耳机会产生 jack 状态边沿并重新初始化路由，所以外放反而恢复。

最终修复需要同时处理冷启动、运行时省电和合盖唤醒。

旧版 v3 对合盖问题的判断方向正确，但把恢复钩子安装到了 `/etc/systemd/system-sleep/`。Ubuntu 26.04 的 systemd 实际只执行 `/usr/lib/systemd/system-sleep/` 中的钩子，因此 v3 的唤醒修复从未运行。短时间合盖测试时功放尚未完全掉电，声音碰巧仍可用，导致当时误以为问题已经解决；一夜 suspend 后功放彻底丢状态，问题才稳定复现。

## 给 AI 的排障方案

如果你准备用 AI 辅助排障，请把这个 prompt 发给 AI：

- 中文：[prompts/ai-troubleshooting.zh-CN.md](prompts/ai-troubleshooting.zh-CN.md)
- English：[prompts/ai-troubleshooting.en.md](prompts/ai-troubleshooting.en.md)

它会提醒 AI 先收集证据、确认 SN6140/CREF-XX 硬件，再做可逆的 HDA verb 测试，不要把问题误判为普通 PipeWire 音量问题。

## 安装

先确认依赖：

```bash
sudo apt install alsa-tools alsa-utils
```

安装：

```bash
git clone https://github.com/lixiang-moss/huawei-sn6140-linux-audio-fix.git
cd huawei-sn6140-linux-audio-fix
sudo bash install.sh
```

安装后建议重启一次：

```bash
sudo reboot
```

安装脚本会启用一个 systemd timer：

```bash
systemctl status huawei-sn6140-audio-fix.timer
```

并安装一个 suspend/resume hook 和独立的恢复服务：

```bash
ls -l /usr/lib/systemd/system-sleep/huawei-sn6140-audio-fix
systemctl status huawei-sn6140-audio-resume-fix.service
```

## 状态检查

```bash
/usr/local/sbin/huawei-sn6140-audio-fix status
```

预期关键值：

```text
/sys/module/snd_hda_intel/parameters/power_save=0
/sys/module/snd_hda_intel/parameters/power_save_controller=N
/sys/bus/pci/devices/0000:00:1f.3/power/control=on
```

某些唤醒失败中，`Speaker` 会变成：

```text
Speaker: Playback 0 [0%] [-74.00dB] [off]
```

手动执行一次修复应能恢复：

```bash
sudo /usr/local/sbin/huawei-sn6140-audio-fix once
```

也可能像 `7.0.0-29-generic` 上的长时间挂起一样，`Speaker` 仍是 `100% [on]`、HDA 电源策略也正确，但外置功放没有响应。这时仍需执行同一套 HDA “先关再开”序列。

## 它做了什么

脚本和安装器做四类事情：

1. 确认机器暴露的是 Conexant SN6140 codec。
2. 确保 ALSA 层 Master/Speaker/PCM 没有静音，并禁用 `Auto-Mute Mode`。
3. 关闭 HDA/PCI 音频运行时省电：

```text
options snd_hda_intel power_save=0 power_save_controller=N
```

并通过 udev 把 Huawei `8086:51c8 / 19e5:3e5f` 音频控制器的 PCI runtime PM 固定为 `on`。

4. 对 SN6140 写入 HDA verb 序列：
   - 先关闭 speaker EAPD。
   - 启用 GPIO bit 1 的 mask 和 direction。
   - GPIO/route 先切到关闭状态。
   - 等 0.4 秒。
   - GPIO/route 再切回扬声器状态。
   - 打开 speaker EAPD。

关键是“先关再开”。只写最终状态在冷启动或唤醒后可能看起来成功，但实际功放仍然不响。

## 开机和合盖唤醒策略

- 开机后 20 秒触发 systemd timer，并在约 2 分钟内重复修复 12 次。
- 合盖 suspend 后再唤醒时，位于 systemd 实际扫描目录中的 hook 会启动独立的 `huawei-sn6140-audio-resume-fix.service`。
- 延迟任务会在唤醒后稍等，再每隔数秒重复修复多次，覆盖 ALSA/WirePlumber/桌面会话陆续恢复并覆盖 mixer 的时间窗口。
- hook 和恢复服务会写入 journal，可用下面的命令确认一次恢复是否真的触发了修复：

```bash
journalctl -b -t huawei-sn6140-audio-sleep
journalctl -b -u huawei-sn6140-audio-resume-fix.service
```

## 卸载

```bash
sudo bash uninstall.sh
sudo reboot
```

卸载会移除脚本、systemd timer、system-sleep hook、modprobe 配置和 udev 规则。重启后内核模块参数和 PCI runtime PM 默认值才会完全恢复。

## 注意事项

- 这个脚本不会播放开机音乐，也不包含 `paplay`、`aplay`、`speaker-test` 等播放命令。
- 如果修复后听到 GNOME 登录旋律，那通常是系统事件音以前因为没声听不到，现在恢复可听了。
- 这个脚本不会改 Windows 分区、EFI 或 GRUB 默认启动项。
- 关闭 HDA 音频省电会略微增加空闲功耗，但通常比周期性丢失外放更可接受。
- 不建议在未确认 SN6140 codec 的机器上使用。

## 排查命令

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
