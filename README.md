# Strato

把专注时间交给一班正在天上飞的真实航班：挑一班两小时后落地的飞机，陪它飞到跑道上，它落地，专注结束，登机牌盖章收进护照。

原生 SwiftUI，iOS 26 及以上，iPhone 和 iPad 通用。没有 Strato 账号或服务器，记录保存在本机，也可连接自己的 iCloud Drive 文件夹自动同步。

## 能做什么

- **实时雷达**：卫星地图上看附近在飞的航班，点一架看航线、高度、速度、机型和机身照片。也可以直接搜航班号。
- **按时长找航班**：说想专注多久，Strato 在全球在飞的航班里找落地时间刚好合适的；可以指定目的地机场，也可选择不限时长。
- **陪飞**：从飞机此刻的真实位置登机。倒计时跟着飞机的实际位置实时修正，可切换地图与离线舷窗，舱位有不同窗框。登机、下降、进近、落地提示音可关闭；也可以只专注固定时长。
- **自选航线**：任选两个机场生成一班模拟航班（界面和记录里都会标明是模拟）。从上次落地机场快速起飞，选择目的地时可查看全程预计时长。
- **登机牌与护照**：每趟航程生成航司配色的登机牌，条码是按 IATA 登机牌格式生成的真 PDF417。落地盖章，收进护照，可分享图片。
- **统计与足迹**：总计、年、月、周、日和周期对比，专注趋势、任务与时段分布、完成结果、常飞航司/航线/机型、连续天数、里程等级。护照支持离线纯色地图、可旋转的 3D 地球及 Apple 地图。
- **系统集成**：落地通知、灵动岛和锁屏实时活动，以及机场快速起飞、航程回顾、绕地球里程和专注趋势小组件。机舱环境音实时合成，不带音频文件。

## 安装（不需要 Mac）

每次推送到 `main` 或 `v3`，GitHub Actions 会在云端 macOS 上编译并打出未签名的安装包：

1. 打开仓库的 **Actions** → 最新一次 **Build** → 页面底部 **Artifacts** → 下载 `Strato-ipa` 并解压。
2. 使用 `Strato.ipa`，带小组件和实时活动。在 SideStore 中更新已有 Strato，保留扩展，沿用原来的签名身份。

应用身份固定为 `com.strato.focus`，小组件扩展为 `com.strato.focus.widget`，共享组为 `group.com.strato.focus`。新增小组件类型都在同一个扩展内。

## 可选同步与 3D 外景

- 在设置的 **iCloud Drive 同步** 中选择 iCloud Drive 文件夹，两台设备选择同一文件夹。应用会在记录变化、返回前台、文件变化和前台定时检查时自动合并。删除也会同步；无网络时保留本机记录，iCloud 文件传输可能有延迟。通过“文件”授予文件夹访问，因此不增加原生 iCloud 容器权限。
- **Google 3D 外景**默认关闭。需要自己的 Google Cloud 项目、启用 Maps 3D SDK for iOS 和计费的 API key；密钥只保存在本机钥匙串。配置后，飞行页面可打开独立外景页，保留 Google 版权标注。中国大陆及澳门无 Maps 3D 覆盖，香港和台湾的覆盖以 Google 实际服务为准。国内可直接使用离线舷窗与离线护照地图。
- Google 的[配置说明](https://developers.google.com/maps/documentation/maps-3d/ios-sdk/setup)与[覆盖表](https://developers.google.com/maps/coverage)。

## 数据从哪来

| 用途 | 来源 |
|---|---|
| 实时位置 | [adsb.fi](https://adsb.fi)，备用 [adsb.lol](https://adsb.lol) |
| 全球快照（找航班用） | [The OpenSky Network](https://opensky-network.org) |
| 航线（起降机场） | adsb.lol 的航线库，备用 [adsbdb](https://www.adsbdb.com) |
| 机身照片 | [Planespotters.net](https://www.planespotters.net) |
| 机场、航司 | [OurAirports](https://ourairports.com)、[OpenFlights](https://openflights.org) |
| 卫星图 | 国内高德，海外 Google，连不上时自动换 Esri；也可切到 Apple 地图 |
| 离线地图轮廓 | [Natural Earth](https://www.naturalearthdata.com)，公共领域数据 |
| 可选 3D 外景 | [Google Maps 3D SDK for iOS](https://developers.google.com/maps/documentation/maps-3d/ios-sdk)，使用用户自己的密钥 |

这些都是免费的公开数据，由爱好者的接收机网络提供，所以有几点要心里有数：

- **覆盖不均**。欧洲、北美、日本很密；中国大陆的接收机少，国内航班能看到的比实际少得多。
- **落地时间是估算**。按飞机当前位置和速度算，进近阶段的模型用真实到港航班校准过，单班误差通常在几分钟内，遇到盘旋等待会更多。倒计时会随飞机位置持续修正。
- **航线靠呼号查表**。查不到或和飞机实际位置对不上的，Strato 宁可显示“航线未知”也不猜。
- 仅供个人非商业使用，不要用于任何和飞行安全有关的事情。

## 工程结构

```
Core/          不依赖 iOS 的逻辑：大圆计算、数据解析、落地时间估算、专注会话、统计。有单元测试。
Shared/        App 和小组件共用：配色、共享数据、实时活动定义。
Strato/        App：地图、界面、声音、通知、存储。
StratoWidget/  小组件和实时活动。
UITests/       在模拟器里用内置的演示数据把完整流程走一遍，并截图。
Scripts/       图标生成、机场/航司数据表生成。
```

- `swift test` 跑 `Core/` 的单元测试（macOS）。
- App 用 [XcodeGen](https://github.com/yonaskolb/XcodeGen) 从 `project.yml` 生成工程：`xcodegen generate`。
- 启动参数 `-demo 1` 让 App 用内置的一组演示航班代替网络，`-demoSpeed N` 让演示时间快 N 倍。
- 机场和航司表由 `Scripts/data/build_reference_data.py` 生成。
