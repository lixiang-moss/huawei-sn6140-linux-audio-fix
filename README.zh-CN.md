# 华为 CREF-XX / Conexant SN6140 Linux 内置扬声器无声修复

[English README](README.md)

这是一个针对 **HUAWEI CREF-XX / M1010** 笔记本在 Ubuntu/Linux 下内置扬声器无声的问题记录和修复脚本。

它不是通用的 “Ubuntu 没声音” 修复。这个方案针对的是：系统已经识别声卡、PipeWire 正常、音量没有静音，但 Conexant SN6140 codec 的扬声器功放在冷启动后没有被正确唤醒。

## 已验证环境

已在以下环境验证：

- 机器：HUAWEI CREF-XX
- 产品版本：M1010
- SKU：C233
- 主板：CREF-XX-PCB
- 系统：Ubuntu 26.04 LTS
- 内核：7.0.0-15-generic
- 音频控制器：Intel Alder Lake PCH-P HDA `8086:51c8`
- PCI subsystem：Huawei `19e5:3e5f`
- Codec：Conexant SN6140
- Codec vendor：`0x14f11f87`
- Codec subsystem：`0x19e53281`

相近机型也可能适用，但请先确认硬件信息。

## 症状

典型症状：

- Ubuntu/Linux 下内置扬声器完全无声。
- Windows 下声音正常。
- `wpctl status` 能看到内置模拟立体声输出。
- `aplay -l` 能看到 `SN6140 Analog`。
- `amixer -c 0 scontents` 中 Master、Speaker、PCM 都不是静音。
- 播放测试音时软件链路看起来正常，但扬声器不响。
- 手动执行 HDA verb “先关再开”序列后立刻有声音。

## 给 AI 的排障方案

如果你准备用 AI 辅助排障，请把这个 prompt 发给 AI：

- 中文：[prompts/ai-troubleshooting.zh-CN.md](prompts/ai-troubleshooting.zh-CN.md)
- English：[prompts/ai-troubleshooting.en.md](prompts/ai-troubleshooting.en.md)

它会提醒 AI 先收集证据、确认 SN6140/CREF-XX 硬件，再做可逆的 HDA verb 测试，不要把问题误判为普通 PipeWire 音量问题。

## 无 AI 手动安装方案

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

安装后会启用一个 systemd timer：

```bash
systemctl status huawei-sn6140-audio-fix.timer
```

它会在开机后 20 秒执行修复，并在第一分钟内重复数次。这样做是因为冷启动后声卡/桌面音频初始化可能会覆盖 codec 状态，单次过早执行不稳定。

## 手动临时测试

如果你只想测试当前会话，不想安装 systemd timer：

```bash
sudo scripts/huawei-sn6140-audio-fix once
```

如果执行后马上有声音，说明你的问题很可能就是 SN6140 扬声器功放冷启动唤醒问题。

## 卸载

```bash
sudo bash uninstall.sh
```

## 它做了什么

脚本做两类事情：

1. 确保 ALSA 层 Master/Speaker/PCM 没有静音。
2. 对 SN6140 写入 HDA verb 序列：
   - 先关闭 speaker EAPD。
   - 启用 GPIO bit 1 的 mask 和 direction。
   - GPIO/route 先切到关闭状态。
   - 等 0.4 秒。
   - GPIO/route 再切回扬声器状态。
   - 打开 speaker EAPD。

关键是“先关再开”。只写最终状态在冷启动后可能看起来成功，但实际功放仍然不响。

## 注意事项

- 这个脚本不会播放开机音乐，也不包含 `paplay`、`aplay`、`speaker-test` 等播放命令。
- 如果修复后听到 GNOME 登录旋律，那通常是系统事件音以前因为没声听不到，现在恢复可听了。
- 这个脚本不会改 Windows 分区、EFI 或 GRUB 默认启动项。
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
sed -n '1,120p' /proc/asound/card0/codec#0
journalctl -k -b --no-pager | grep -iE 'snd|hda|sof|avs|conexant|SN6140'
```

## 标题建议

如果你要发布到 GitHub，可以用下面的仓库名或文章标题：

- `huawei-sn6140-linux-audio-fix`
- `Huawei CREF-XX Conexant SN6140 Linux Speaker Fix`
- `Ubuntu 26.04 Huawei CREF-XX No Sound Fix`
- `Fix Huawei MateBook CREF-XX SN6140 Speakers on Linux`

## 发布前检查

用这个目录作为根目录创建一个独立 GitHub 仓库。不要把它复制进无关项目仓库里。
