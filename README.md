# Strato (平流层)

**iOS 26 / iOS 27 原生 Liquid Glass（液态玻璃）专注伴飞与实时航班追踪应用**

> 没有 Mac 也能完整编译打包：本项目采用 **SwiftUI + MapKit + WidgetKit + ActivityKit** 原生架构，配合 **XcodeGen + GitHub Actions (`macos-26`)** 云端自动生成未签名 `.ipa`，直接用 **SideStore / LiveContainer / AltStore / Sideloadly** 自签安装到你的 iPhone 与 iPad。

---

## 核心功能

1. **实时 ADS-B 航班伴飞（免 API Key 开箱即用）**
   - 默认直连 `opendata.adsb.fi` 与 `adsb.lol` 开源实时 ADS-B 雷达与航线库，无需申请任何付费 Key。
   - 实时获取天上在飞航班的经纬度、气压高度（Flight Level）、地速（Knots）、航向角与起降机场。
   - **按专注时长智能推飞机**：比如你想专注 2 小时，Strato 会自动扫描当前空域、按大圆航线剩余距离与实时地速，优先推荐**还剩约 2 小时降落**的真实航班陪你一起飞。
   - **自选目的地 & 离线校准模拟**：支持筛选指定降落机场，或自选全球 50+ 核心机场生成定制伴飞航线。

2. **iOS 26 / 27 原生 Liquid Glass（液态玻璃）界面**
   - 全面采用苹果原生 `.glassEffect()`、`GlassEffectContainer` 与 `.buttonStyle(.glassProminent)`。
   - 适配 iPhone 与 iPad（`.tabViewStyle(.sidebarAdaptable)`），包含深空卫星地图、航迹发光弧线、登机牌专注卡与平流层机舱白噪音（`AVAudioEngine` 实时合成，零音频文件体积）。

3. **飞行护照（Logbook）与登机牌存档**
   - 每次伴飞降落自动盖章生成登机牌，记录航班号、机型、起降机场、专注标签、座位号与累计飞行里程，并在护照世界地图上点亮你的大圆航迹。

4. **桌面小组件 & 灵动岛 / 锁屏实时活动（Live Activity）**
   - `StratoWidget` 提供桌面小组件（实时航程进度 / 累计飞行护照统计）以及灵动岛 & 锁屏实时航班进度条。

---

## 没有 Mac 如何一键云端打包 `.ipa` 并装到手机

### 第一步：推送到你的 GitHub 仓库
在当前目录打开终端（或让我帮你直接推上去）：
```bash
git init
git add .
git commit -m "Initial commit: Strato iOS 26 Liquid Glass Focus App"
git branch -M main
git remote add origin https://github.com/<你的GitHub用户名>/Strato.git
git push -u origin main
```

### 第二步：在 GitHub Actions 下载 `.ipa`
1. 打开你 GitHub 仓库顶部的 **Actions** 标签页。
2. 你会看到 **Build Strato Unsigned IPA** 自动开始运行（耗时约 2~3 分钟）。
   - **小贴士（省 App ID 额度）**：如果你用免费 Apple ID 在 SideStore 里签名、不想让小组件多占 1 个 App ID，可以在 Actions 页面手动点 **Run workflow**，把 `Include Home Screen Widget & Live Activity extension` 设为 `false`，打出来的就是只占 1 个 App ID 的纯主包。
3. 编译完成后，滑到底部 **Artifacts** 下载 `Strato-unsigned-ipa`，解压得到 `Strato-unsigned.ipa`。

### 第三步：用 SideStore / LiveContainer 自签安装
- 把原有的普通软件挪进 **LiveContainer**，腾出 1 个 SideStore 原生槽位给 `Strato-unsigned.ipa`，即可完整使用 Strato 的原生液态玻璃界面、桌面小组件与灵动岛。
