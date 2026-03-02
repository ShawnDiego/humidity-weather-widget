# HumidityWeather

跨 iOS 17+ / macOS 14+ 的可配置天气组件示例工程。

## 已实现能力

- `SwiftUI + WidgetKit + AppIntent` 双平台（iOS/macOS）
- 每个组件实例可独立配置：显示方案、位置模式、手动城市
- 字段可选且可排序：湿度、天气现象、太阳光照、日照时长、风速、风向等
- 数据源策略：`QWeather` 主源 + `Open-Meteo` 兜底/补充
- 缓存策略：30 分钟 TTL，3 小时过期容忍
- 刷新策略：时间线 6 小时、30 分钟粒度；失败退避到 60 分钟

## 工程结构

- `WeatherCore/`：模型、存储、Provider、Repository、格式化与测试
- `WeatherApp/`：配置 App（方案管理、定位、设置）
- `WeatherWidgetExtension/`：Widget 及 AppIntent 配置
- `project.yml`：XcodeGen 配置（生成 `HumidityWeather.xcodeproj`）

## 本地使用

1. 生成工程：`xcodegen generate`
2. 打开：`HumidityWeather.xcodeproj`
3. 在 App 的“应用设置”中填写和风天气 API Key（可留空，自动回退 Open-Meteo）
4. 在 App 的“定位设置”中更新当前位置
5. 添加 Widget，选择显示方案与位置模式

## 验证命令

- Core 测试：`cd WeatherCore && swift test`
- iOS 构建：
  `xcodebuild -project HumidityWeather.xcodeproj -scheme WeatherAppiOS -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build`
- macOS 构建：
  `xcodebuild -project HumidityWeather.xcodeproj -scheme WeatherAppmacOS -destination 'generic/platform=macOS' CODE_SIGNING_ALLOWED=NO build`
