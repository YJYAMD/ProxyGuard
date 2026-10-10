<div align="center">

# 🛡️ ProxyGuard for macOS

**极致轻量、优雅通透的 macOS 原生代理状态守护与实时网速监控应用**

[![Platform](https://img.shields.io/badge/Platform-macOS%2012.0+-black.svg?style=flat-square&logo=apple)](https://www.apple.com/macos/)
[![Language](https://img.shields.io/badge/Language-Swift%206-orange.svg?style=flat-square&logo=swift)](https://swift.org/)
[![License](https://img.shields.io/badge/License-MIT-blue.svg?style=flat-square)](LICENSE)
[![Zero-Dependency](https://img.shields.io/badge/Dependencies-Zero-brightgreen.svg?style=flat-square)]()

[English Document](README_EN.md) · [简体中文](README.md)

</div>

---

### 💡 为什么需要 ProxyGuard？

在使用代理软件（如 **Clash Verge / ClashX / Surge / Mihomo / Sing-box** 等）时，常常遇到以下痛点：
1. **静默断网**：代理节点超时或客户端闪退后，macOS 系统代理依然开启，所有应用（浏览器、微信、终端）瞬间全断，难以及时察觉；
2. **缺乏状态感知**：状态栏只显示客户端图标，不知道当前节点通不通、延迟多高、处于哪个国家；
3. **想看代理真实网速**：系统的活动监视器只能看整张网卡的全部流量，无法单独统计**真正流经代理**的实时上下行流量。

**ProxyGuard** 应运而生 —— 它直接常驻在 macOS 顶部状态栏，提供秒级断网感知、毫秒级延迟测定、真实代理速率统计与国家/地区识别。

---

### ✨ 核心特性

- 🟢 **秒级断网感知与闪烁警报**：
  - 默认每秒探活。节点断开或端口失效时，**1.5 秒内立即变红**；
  - 触发**呼吸脉搏闪烁动画**，并推送 macOS 原生横幅声音告警；
  - 节点恢复后自动重连并发送恢复提示。
- ⚡️ **真实代理速率显示**：
  - 在状态圆点旁实时展示当前**真正走代理的网速**（例如 `🟢 🇺🇸 1.25 MB/s`）；
  - 直连 Clash / Mihomo 核心 Unix Socket，数据 100% 精准，绝不掺杂局域网流量；
  - 采用 Apple 原生 **等宽数字字体（`monospacedDigitSystemFont`）**，数值跳动绝不左右晃动。
- 🌍 **自动识别节点国家与出口地区**：
  - 顶部直接渲染对应国家的国旗（`🇺🇸`、`🇯🇵`、`🇭🇰`、`🇸🇬` 等）；
  - 下拉卡片清晰展示**出口国家/地区、节点全称、真实出口 IP**。
- 🎨 **苹果级微质感 UI（Apple HIG 美学）**：
  - 提供 4 种精美外观样式自由切换：
    - 🔮 **霓虹晶体呼吸灯**（多阶纵向渐变 + 镜面高光透镜）
    - 💊 **灵动高科技胶囊**（紧凑圆角药丸，极配电池瓦数显示）
    - 🎯 **精密极客光环**（双层精密同心环）
    - 💎 **微光珠宝圆点**（极简 7pt 钛金属微圈）
  - 全新**毛玻璃悬浮卡片仪表盘**，信息层次分明，自动跟随 macOS 深色/浅色模式自适应。
- 🍃 **极致轻量，零第三方依赖**：
  - 纯原生 Swift + AppKit 编写，单二进制文件仅约 **120 KB**；
  - 内存占用仅 **~15 MB**，CPU 占用稳定在 **~1%**，耗电几乎为零。
- 📌 **支持 ⌘ + 鼠标随意拖拽重排**：
  - 支持按住键盘 `Command (⌘)` 将图标拖动到菜单栏任意位置（如电池瓦数左侧）；
  - 系统级永久记忆位置，重启不移位。

---

### 🚀 快速安装

#### 方式一：一键自动安装（推荐）

打开终端，直接运行：

```bash
git clone https://github.com/YJYAMD/ProxyGuard.git
cd ProxyGuard
./scripts/install.sh
```

脚本将自动编译并安装到 `/Applications/ProxyGuard.app`，随后立即在菜单栏启动！

#### 方式二：手动编译

```bash
./scripts/build.sh
open build/ProxyGuard.app
```

---

### ⚙️ 使用说明

1. **调整位置**：
   * 按住键盘 **`⌘ (Command)`** 键不放，用鼠标按住顶部的圆点拖拽，即可放到电池瓦数或任意图标旁边。
2. **呼出仪表盘**：
   * 单击菜单栏图标，即可展开毛玻璃卡片查看节点国家、出口 IP、延迟、端口、实时上下行速率与累计使用流量。
3. **自定义设置**：
   * **图标样式**：在「图标视觉样式」中切换 4 种设计风格；
   * **速率单位**：在「速率显示设置」中选择 `0.00 MB/s`、`0.00 M/s` 或 `自动单位`；
   * **开机自启**：在菜单中点击「开机自动启动」即可一键设置。

---

### 📁 项目结构

```text
ProxyGuard/
├── Sources/
│   └── main.swift           # 完整的原生 Swift 源码
├── scripts/
│   ├── build.sh             # 编译打包脚本
│   ├── install.sh           # 一键安装脚本
│   └── uninstall.sh         # 一键卸载脚本
├── .github/
│   └── workflows/
│       └── release.yml      # GitHub Actions 自动化构建
├── Info.plist               # macOS 应用程序配置
├── LICENSE                  # MIT 开源许可证
└── README.md                # 项目中文文档
```

---

### 🤝 贡献与反馈

欢迎提 Issue、PR 共同完善 ProxyGuard！
如果您觉得好用，欢迎点亮右上角的 ⭐️ **Star** 支持一下！

---

### 📄 许可证

本项目基于 [MIT License](LICENSE) 开源。
