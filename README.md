# HumidityWeather

跨 iOS 17+ / macOS 14+ 的可配置天气 Widget 工程。支持多数据源、可定制显示方案、完整的缓存与回退策略。

---

## 工程结构

```
HumidityWeather/
├── WeatherCore/                 # 核心库（SPM，平台无关）
│   ├── Models/                  # AppConfig、Settings、WeatherModels、WeatherError
│   ├── Providers/               # QWeatherProvider、OpenMeteoProvider、Composite*
│   ├── Services/                # WeatherRepository、WeatherServiceFactory
│   ├── Storage/                 # 五个 Actor Store（Profile、Location、Settings、Cache、Widget）
│   ├── Networking/              # NetworkClient、URLRequestBuilder
│   ├── Formatting/              # WeatherFormatter、DateParser
│   └── Tests/WeatherCoreTests/  # Swift Testing 单元测试（13 项）
├── WeatherApp/                  # 配置 App（SwiftUI）
├── WeatherWidgetExtension/      # WidgetKit + AppIntent Widget
├── Config/                      # 授权文件（.entitlements）
└── project.yml                  # XcodeGen 工程配置
```

---

## 数据源

### 主源：和风天气（QWeather）

需要用户在 App「设置」中填写 API Key；Key 留空时自动完全回退到 Open-Meteo。

| 端点 | 用途 |
|------|------|
| `GET /v7/weather/now` | 实时天气（温度、湿度、风速/向、气压、能见度、体感温度、天气现象代码） |
| `GET /v7/astronomy/sun` | 日出/日落时间 |
| `GET /v2/city/lookup` | 城市名称 → 坐标 + 时区（Geocoding） |

### 备源：Open-Meteo（免费，无需 Key）

| 端点 | 用途 |
|------|------|
| `GET /v1/forecast` | 实时 + 每日天气（含太阳辐照度、UV 指数、降水概率、日照时长、日出/日落） |
| `GET /v1/search` | 城市 Geocoding（WMO 标准） |

### 数据合并策略

- 双源并行请求，主源数据优先；主源缺失的字段由备源补齐（`CompositeWeatherProvider`）。
- Geocoding 同理：`QWeatherCityGeocoder` → `OpenMeteoCityGeocoder`（`CompositeCityGeocoder`）。

---

## 天气指标

支持 12 项可选指标，用户可在显示方案中任意勾选、拖拽排序：

| 标识符 | 中文名 | 英文名 | 单位（公制 / 英制） | 数据来源 |
|--------|--------|--------|---------------------|---------|
| `temperature` | 温度 | Temperature | °C / °F | 双源 |
| `humidity` | 湿度 | Humidity | % | 双源 |
| `condition` | 天气 | Condition | 图标 + 描述 | 双源 |
| `windSpeed` | 风速 | Wind Speed | km/h / mph | 双源 |
| `windDirection` | 风向 | Wind Direction | 方位角 → N/NE/… | 双源 |
| `feelsLike` | 体感温度 | Feels Like | °C / °F | 双源 |
| `pressure` | 气压 | Pressure | hPa / inHg | 双源 |
| `visibility` | 能见度 | Visibility | km / mi | 双源 |
| `daylightDuration` | 日照时长 | Daylight | h（由日出/日落计算） | 双源 |
| `solarIrradiance` | 太阳光照 | Solar Irradiance | W/m² | Open-Meteo 专属 |
| `uvIndex` | UV 指数 | UV Index | 指数 | Open-Meteo 专属 |
| `precipitationProbability` | 降水概率 | Precip. Chance | % | Open-Meteo 专属 |

---

## 显示方案（Profile）

- 每个方案包含：名称、指标列表（有序可去重）、单位系统（自动 / 公制 / 英制）。
- 方案以 UUID 为主键，存储于 App Group 的 `UserDefaults`，Widget 与 App 共享。
- 默认方案预置 6 项指标：温度、湿度、天气、风速、风向、日照时长。
- Widget 可独立绑定任意方案（通过 AppIntent 配置）。

---

## Widget

**类型：** `CurrentWeatherWidget`（AppIntent 可配置）

| 尺寸 | 最多显示指标数 | 布局 |
|------|-------------|------|
| Small | 3 | 单列 |
| Medium | 6 | 双列 |
| Large | 10 | 双列 |

**界面组成：**

- **头部**：城市名 + 更新时间 + 天气描述 + 天气图标（按天气类型着色）+ 主温度
- **指标网格**：图标 + 本地化名称 + 格式化值（温度不重复出现在网格中）
- **陈旧数据提示**：数据超过 30 分钟时显示橙色警告标签

**天气类型着色（10 种）：**

| 类型 | 颜色 |
|------|------|
| 晴（白天）| 黄色 |
| 晴（夜间）| 蓝色 |
| 局部多云 | 橙色 |
| 多云 | 灰色 |
| 有雾 | 深灰 |
| 霾 | 棕色 |
| 雨 | 蓝色 |
| 雪 | 青色 |
| 雷暴 | 靛蓝 |
| 大风 | 薄荷绿 |

**交互：** 点击 Widget 可通过 DeepLink（`humidity://weather?profileId=…&location=…`）跳转到 App 对应方案页。

---

## App 功能

### 显示方案（Tab 1）

- 列表展示所有方案及指标预览
- 新建 / 编辑 / 删除方案
- 方案编辑器：名称、单位系统、指标勾选 + 拖拽排序

### 定位（Tab 2）

- 展示定位权限状态，支持申请权限 / 手动刷新
- 保存当前位置（城市名、经纬度、时区）
- 自动反向地理编码（`CLLocationManager` + `CLGeocoder`）
- 定位精度：3 km；无法解析城市名时回退到「当前位置」

### 设置（Tab 3）

- 和风天气 API Key 输入与保存（自动去除首尾空白）
- API 连通性测试（以北京坐标测试）
- Debug 开关：在 Widget 中显示数据来源标注

---

## 缓存策略

| 参数 | 值 |
|------|----|
| 实时窗口（cacheTTL） | 30 分钟 |
| 陈旧容忍窗口（staleWindow） | 3 小时 |
| 存储位置 | App Group 共享容器 `WeatherCache/` 目录 |
| 格式 | JSON（`CachedSnapshotEnvelope`：时间戳 + 快照） |
| 文件名哈希 | CryptoKit SHA-256（Apple 平台）/ FNV-1a 64-bit（Linux/测试） |

**刷新判断逻辑：**

```
age = now − fetchedAt
age ≤ 30 min         → LIVE（正常显示）
30 min < age ≤ 3 h   → STALE（显示陈旧提示）
age > 3 h            → EXPIRED（丢弃，重新请求）
```

**Widget 时间线刷新：**

- 实时数据：30 分钟粒度，共 13 个时间点（0 ～ 360 分钟）
- 陈旧数据：60 分钟粒度
- 请求失败：退避到 60 分钟后重试

---

## 本地化

| 语言 | 状态 |
|------|------|
| 简体中文 | 主语言 |
| English | 回退语言 |

本地化覆盖范围：指标名称、单位系统名称、天气状况描述（10 种）、风向（8 方位）、界面文字。  
单位系统支持「自动（按地区）」：美国地区默认英制，其余默认公制。

---

## 配置常量（AppConfig）

| 常量 | 值 |
|------|----|
| `appGroup` | `group.com.diego.humidity` |
| `qWeatherBaseURL` | `https://devapi.qweather.com/v7` |
| `qWeatherGeoBaseURL` | `https://geoapi.qweather.com/v2` |
| `openMeteoBaseURL` | `https://api.open-meteo.com/v1` |
| `openMeteoGeoBaseURL` | `https://geocoding-api.open-meteo.com/v1` |
| `cacheTTL` | 1800 s（30 min） |
| `staleWindow` | 10800 s（3 h） |
| `requestTimeout` | 8 s |

---

## 架构要点

- **Actor 并发安全**：所有 Store（`DisplayProfileStore`、`LocationStore`、`SettingsStore`、`SnapshotCacheStore`、`WidgetConfigStore`）及 `WeatherRepository` 均为 `actor`。
- **协议驱动**：`WeatherProvider`、`CityGeocoder`、`NetworkClient` 均为协议，便于 Mock 测试。
- **工厂模式**：`WeatherServiceFactory` 统一创建 Provider 与 Repository，延迟初始化。
- **SwiftUI + WidgetKit + AppIntent**：Widget 配置完全通过 AppIntent 驱动，无需独立配置界面。
- **跨平台 SPM**：`WeatherCore` 为独立 Swift Package，可在 Linux/macOS 命令行直接构建和测试。

---

## 测试覆盖（13 项）

| 测试项 | 内容 |
|--------|------|
| `displayProfileDeduplicatesMetrics` | 方案去重 |
| `cacheFreshnessRespectsTTLAndStaleWindow` | 缓存 live/stale/expired 三个区间 |
| `compositeProviderMergesMissingMetricsFromFallback` | 双源合并缺失字段 |
| `formatterSupportsUnitAndLanguageLocalization` | 单位转换 + 中英文名称 |
| `formatterMapsConditionToLocalizedDescriptionAndSymbols` | 天气代码 → 描述 + SF Symbol（日/夜） |
| `dateParserHandlesOpenMeteoLocalTimeFormat` | 本地时间字符串解析（带时区） |
| `qWeatherSunDateUsesLocalTimezone` | 日出/落使用本地时区日期 |
| `formatterWindDirectionHandlesEdgeCasesAndNormalization` | 风向归一化（0°/360°/负角度） |
| `compositeCityGeocoderFallsBackToSecondaryOnPrimaryFailure` | Geocoding 主源失败回退备源 |
| `compositeCityGeocoderUsesPrimaryWhenAvailable` | 优先使用主 Geocoding 源 |
| `compositeCityGeocoderWithNilPrimaryUsesSecondary` | 主源为 nil 时使用备源 |
| `repositoryFallsBackToStaleCacheOnProviderFailure` | Provider 失败时回退陈旧缓存 |
| `repositoryThrowsWhenNoProviderDataAndNoCache` | 无数据无缓存时正确抛出错误 |

---

## 验证命令

```bash
# Core 单元测试（Linux / macOS，无需 Xcode）
cd WeatherCore && swift test

# 生成 Xcode 工程（需安装 XcodeGen）
xcodegen generate

# iOS 构建
xcodebuild -project HumidityWeather.xcodeproj \
           -scheme WeatherAppiOS \
           -destination 'generic/platform=iOS Simulator' \
           CODE_SIGNING_ALLOWED=NO build

# macOS 构建
xcodebuild -project HumidityWeather.xcodeproj \
           -scheme WeatherAppmacOS \
           -destination 'generic/platform=macOS' \
           CODE_SIGNING_ALLOWED=NO build
```

---

## 使用步骤

1. 生成工程：`xcodegen generate`
2. 打开 `HumidityWeather.xcodeproj`，选择目标设备后运行
3. 在 App「设置」中填写和风天气 API Key（可留空，自动回退到 Open-Meteo）
4. 在 App「定位」中授予定位权限或手动刷新位置
5. 添加 Widget，长按进入编辑，选择显示方案与位置模式
