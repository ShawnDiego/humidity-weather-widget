import SwiftUI
import Charts
import WeatherCore

struct WeatherHomeView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.locale) private var locale

    let onSelectTab: (AppTab) -> Void
    @State private var selectedMetric: DashboardMetric?

    var body: some View {
        NavigationStack {
            ZStack {
                WeatherSceneBackground(
                    category: conditionCategory,
                    isNight: isNight
                )

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        AppSectionHeader(
                            title: loc("天气", "Weather"),
                            subtitle: headerSubtitle
                        )

                        if model.weatherLoadState == .refreshing, model.currentSnapshot != nil {
                            AppCard {
                                HStack(spacing: 12) {
                                    ProgressView()
                                        .tint(.white)
                                    Text(loc("正在更新最新天气...", "Refreshing latest weather..."))
                                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.86))
                                }
                            }
                        }

                        content

                        QuickActionsCard(onSelectTab: onSelectTab, locale: locale)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 18)
                    .padding(.bottom, 26)
                    .frame(maxWidth: 960)
                    .frame(maxWidth: .infinity)
                }
                .refreshable {
                    await model.refreshCurrentWeather(force: true)
                }
            }
            .navigationTitle(loc("天气", "Weather"))
            .toolbar {
#if os(iOS)
                ToolbarItem(placement: .topBarTrailing) {
                    refreshButton
                }
#else
                ToolbarItem(placement: .primaryAction) {
                    refreshButton
                }
#endif
            }
            .sheet(item: $selectedMetric) { metric in
                if let snapshot = model.currentSnapshot?.snapshot {
                    HourlyMetricChartSheet(
                        metric: metric,
                        snapshot: snapshot,
                        unitSystem: .auto,
                        locale: locale
                    )
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 36, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                        Text(loc("暂无可用图表数据", "Chart data is unavailable right now"))
                            .font(.system(.headline, design: .rounded, weight: .bold))
                    }
                    .padding(24)
                    .presentationDetents([.medium])
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.weatherLoadState {
        case .idle, .loading:
            LoadingStateCard(locale: locale)
        case .emptyLocation:
            EmptyLocationCard(locale: locale) {
                onSelectTab(.location)
            }
        case .failed:
            ErrorStateCard(
                message: model.weatherErrorMessage,
                locale: locale,
                onRetry: {
                    Task {
                        await model.refreshCurrentWeather(force: true)
                    }
                },
                onOpenLocation: {
                    onSelectTab(.location)
                },
                onOpenSettings: {
                    onSelectTab(.settings)
                }
            )
        case .refreshing, .loaded:
            if let snapshotResult = model.currentSnapshot {
                loadedContent(snapshotResult)
            } else {
                LoadingStateCard(locale: locale)
            }
        }
    }

    @ViewBuilder
    private func loadedContent(_ snapshotResult: SnapshotResult) -> some View {
        let snapshot = snapshotResult.snapshot

        HeroWeatherCard(
            snapshot: snapshot,
            freshness: snapshotResult.freshness,
            isNight: isNight,
            locale: locale
        )

        if snapshotResult.freshness == .stale {
            AppCard {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                        .font(.system(.title3, design: .rounded))
                        .foregroundStyle(Color.orange)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(loc("当前显示缓存天气", "Showing cached weather"))
                            .font(.system(.headline, design: .rounded, weight: .bold))
                            .foregroundStyle(.white)
                        Text(loc(
                            "实时请求失败，页面已回退到最近一次成功获取的数据。",
                            "The live request failed, so the dashboard is using the most recent successful snapshot."
                        ))
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(.white.opacity(0.74))
                    }

                    Spacer(minLength: 12)

                    Button(loc("重试", "Retry")) {
                        Task {
                            await model.refreshCurrentWeather(force: true)
                        }
                    }
                    .buttonStyle(AppSecondaryButtonStyle())
                }
            }
        }

        if !dashboardMetrics(snapshot).isEmpty {
            WeatherMetricGridCard(
                title: loc("关键指标", "Key Metrics"),
                subtitle: loc("实时关注湿度、体感、风与空气条件", "Track humidity, feels-like, wind, and air conditions at a glance"),
                metrics: dashboardMetrics(snapshot),
                locale: locale,
                onSelectMetric: { metric in
                    selectedMetric = metric
                }
            )
        }

        if !sunlightRows(snapshot).isEmpty {
            SunlightCard(rows: sunlightRows(snapshot), locale: locale)
        }
    }

    private var refreshButton: some View {
        Button {
            Task {
                await model.refreshCurrentWeather(force: true)
            }
        } label: {
            Image(systemName: "arrow.clockwise")
                .font(.system(.body, design: .rounded, weight: .semibold))
        }
        .disabled(model.weatherLoadState == .loading || model.weatherLoadState == .refreshing)
    }

    private var headerSubtitle: String {
        if let location = model.storedLocation?.name {
            return loc(
                "为 \(location) 展示实时天气与关键环境指标",
                "Live weather and key environmental metrics for \(location)"
            )
        }

        return loc(
            "保存当前位置后，这里会变成你的实时天气首页",
            "Save your current location and this becomes your live weather dashboard"
        )
    }

    private var conditionCategory: WeatherConditionCategory? {
        guard let conditionCode = model.currentSnapshot?.snapshot.conditionCode else {
            return nil
        }
        return WeatherFormatter.weatherCategory(for: conditionCode)
    }

    private var isNight: Bool {
        guard let snapshot = model.currentSnapshot?.snapshot else {
            return false
        }

        if let sunrise = snapshot.sunrise, let sunset = snapshot.sunset {
            return snapshot.timestamp < sunrise || snapshot.timestamp >= sunset
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: snapshot.timezone) ?? .current
        let hour = calendar.component(.hour, from: snapshot.timestamp)
        return hour < 6 || hour >= 18
    }

    private func dashboardMetrics(_ snapshot: WeatherSnapshot) -> [DashboardMetric] {
        let ordered: [WeatherMetric] = [
            .humidity,
            .feelsLike,
            .windSpeed,
            .windDirection,
            .pressure,
            .visibility,
            .uvIndex,
            .precipitationProbability
        ]

        return ordered.compactMap { metric in
            guard let value = snapshot.values[metric] else { return nil }
            return DashboardMetric(
                metric: metric,
                valueText: WeatherFormatter.formattedValue(
                    metric: metric,
                    value: value,
                    unitSystem: .auto,
                    locale: locale
                )
            )
        }
    }

    private func sunlightRows(_ snapshot: WeatherSnapshot) -> [SunlightRow] {
        var rows: [SunlightRow] = []

        if let sunrise = snapshot.sunrise {
            rows.append(
                SunlightRow(
                    symbol: "sunrise.fill",
                    title: loc("日出", "Sunrise"),
                    value: sunrise.formatted(date: .omitted, time: .shortened)
                )
            )
        }

        if let sunset = snapshot.sunset {
            rows.append(
                SunlightRow(
                    symbol: "sunset.fill",
                    title: loc("日落", "Sunset"),
                    value: sunset.formatted(date: .omitted, time: .shortened)
                )
            )
        }

        let daylightHours = snapshot.values[.daylightDuration] ?? {
            guard let sunrise = snapshot.sunrise, let sunset = snapshot.sunset else {
                return nil
            }
            return max(0, sunset.timeIntervalSince(sunrise) / 3600)
        }()

        if let daylightHours {
            rows.append(
                SunlightRow(
                    symbol: "sun.max.fill",
                    title: loc("日照时长", "Daylight"),
                    value: WeatherFormatter.formattedValue(
                        metric: .daylightDuration,
                        value: daylightHours,
                        unitSystem: .auto,
                        locale: locale
                    )
                )
            )
        }

        return rows
    }

    private func loc(_ zh: String, _ en: String) -> String {
        WeatherFormatter.prefersChineseSystem(locale) ? zh : en
    }
}

private struct WeatherSceneBackground: View {
    let category: WeatherConditionCategory?
    let isNight: Bool

    var body: some View {
        AppGradientBackground(category: category, isNight: isNight)
    }
}

private struct HeroWeatherCard: View {
    let snapshot: WeatherSnapshot
    let freshness: SnapshotFreshness
    let isNight: Bool
    let locale: Locale

    private var theme: WeatherWidgetTheme {
        WeatherWidgetTheme(
            category: WeatherFormatter.weatherCategory(for: snapshot.conditionCode),
            isNight: isNight
        )
    }

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(snapshot.locationName)
                            .font(.system(.title3, design: .rounded, weight: .bold))
                            .foregroundStyle(.white)

                        Text(WeatherFormatter.conditionDescription(for: snapshot.conditionCode, locale: locale))
                            .font(.system(.body, design: .rounded, weight: .medium))
                            .foregroundStyle(.white.opacity(0.86))

                        Text(updatedAtText)
                            .font(.system(.footnote, design: .rounded, weight: .medium))
                            .foregroundStyle(.white.opacity(0.68))
                    }

                    Spacer(minLength: 12)

                    VStack(alignment: .trailing, spacing: 10) {
                        StatusBadge(
                            text: freshness == .stale ? loc("缓存", "Cached") : loc("实时", "Live"),
                            tone: freshness == .stale ? .warning : .good
                        )

                        WeatherGlyph(
                            category: WeatherFormatter.weatherCategory(for: snapshot.conditionCode),
                            isNight: isNight,
                            size: 58,
                            palette: theme.glyphPalette
                        )
                        .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 4)
                    }
                }

                HStack(alignment: .bottom, spacing: 16) {
                    Text(temperatureText)
                        .font(.system(size: 54, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .contentTransition(.numericText())

                    Spacer(minLength: 0)

                    if let feelsLikeText {
                        SpotlightPill(
                            title: loc("体感", "Feels Like"),
                            value: feelsLikeText,
                            accent: theme.conditionAccent
                        )
                    }
                }

                HStack(spacing: 12) {
                    if let humidityText {
                        HumidityHighlightCard(value: humidityText, accent: theme.conditionAccent, locale: locale)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Label(loc("数据来源", "Data Source"), systemImage: "dot.radiowaves.left.and.right")
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.68))

                        Text(snapshot.source)
                            .font(.system(.body, design: .rounded, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.92))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                    .background(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        }
    }

    private var temperatureText: String {
        guard let value = snapshot.values[.temperature] else {
            return "--"
        }

        return WeatherFormatter.formattedValue(
            metric: .temperature,
            value: value,
            unitSystem: .auto,
            locale: locale
        )
    }

    private var feelsLikeText: String? {
        guard let value = snapshot.values[.feelsLike] else {
            return nil
        }

        return WeatherFormatter.formattedValue(
            metric: .feelsLike,
            value: value,
            unitSystem: .auto,
            locale: locale
        )
    }

    private var humidityText: String? {
        guard let value = snapshot.values[.humidity] else {
            return nil
        }

        return WeatherFormatter.formattedValue(
            metric: .humidity,
            value: value,
            unitSystem: .auto,
            locale: locale
        )
    }

    private var updatedAtText: String {
        let prefix = freshness == .stale ? loc("缓存于", "Cached at") : loc("更新于", "Updated")
        return "\(prefix) \(snapshot.timestamp.formatted(date: .omitted, time: .shortened))"
    }

    private func loc(_ zh: String, _ en: String) -> String {
        WeatherFormatter.prefersChineseSystem(locale) ? zh : en
    }
}

private struct HumidityHighlightCard: View {
    let value: String
    let accent: Color
    let locale: Locale

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(loc("湿度", "Humidity"), systemImage: "humidity.fill")
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(.white.opacity(0.72))

            Text(value)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(
            LinearGradient(
                colors: [
                    accent.opacity(0.34),
                    Color.white.opacity(0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func loc(_ zh: String, _ en: String) -> String {
        WeatherFormatter.prefersChineseSystem(locale) ? zh : en
    }
}

private struct SpotlightPill: View {
    let title: String
    let value: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(.white.opacity(0.70))
            Text(value)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(accent.opacity(0.22))
        .overlay(
            Capsule(style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .clipShape(Capsule(style: .continuous))
    }
}

private struct WeatherMetricGridCard: View {
    let title: String
    let subtitle: String
    let metrics: [DashboardMetric]
    let locale: Locale
    let onSelectMetric: (DashboardMetric) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.white.opacity(0.70))
                }

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(metrics) { metric in
                        WeatherMetricTile(
                            metric: metric,
                            locale: locale,
                            action: { onSelectMetric(metric) }
                        )
                    }
                }
            }
        }
    }
}

private struct WeatherMetricTile: View {
    let metric: DashboardMetric
    let locale: Locale
    let action: (() -> Void)?

    var body: some View {
        Group {
            if let action {
                Button(action: action) {
                    tileBody
                }
                .buttonStyle(.plain)
            } else {
                tileBody
            }
        }
    }

    private var tileBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: WeatherFormatter.metricSymbol(for: metric.metric))
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.72))
                Text(WeatherFormatter.localizedMetricName(metric.metric, locale: locale))
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.70))
                    .lineLimit(1)

                Spacer(minLength: 0)

                if action != nil {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundStyle(.white.opacity(0.58))
                }
            }

            Text(metric.valueText)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct HourlyMetricChartSheet: View {
    let metric: DashboardMetric
    let snapshot: WeatherSnapshot
    let unitSystem: UnitSystem
    let locale: Locale

    private var samples: [HourlyChartSample] {
        snapshot.hourly
            .sorted { $0.timestamp < $1.timestamp }
            .compactMap { point in
                guard let rawValue = point.values[metric.metric] else { return nil }
                return HourlyChartSample(
                    timestamp: point.timestamp,
                    value: convertedChartValue(rawValue, metric: metric.metric)
                )
            }
            .prefix(24)
            .map { $0 }
    }

    private var resolvedUnitSystem: UnitSystem {
        WeatherFormatter.effectiveUnitSystem(unitSystem, locale: locale)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                WeatherSceneBackground(
                    category: WeatherFormatter.weatherCategory(for: snapshot.conditionCode),
                    isNight: isNight
                )

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        AppCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(WeatherFormatter.localizedMetricName(metric.metric, locale: locale))
                                    .font(.system(.title3, design: .rounded, weight: .bold))
                                    .foregroundStyle(.white)

                                Text(loc("未来 24 小时趋势", "Hourly trend for the next 24 hours"))
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.72))

                                Text(metric.valueText)
                                    .font(.system(.title, design: .rounded, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }

                        if samples.isEmpty {
                            AppCard {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(loc("暂无小时级数据", "No hourly data available"))
                                        .font(.system(.headline, design: .rounded, weight: .bold))
                                        .foregroundStyle(.white)
                                    Text(loc(
                                        "当前数据源还没有返回这个指标的逐小时预报，请稍后重试。",
                                        "The active weather source did not return hourly forecast data for this metric yet."
                                    ))
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.72))
                                }
                            }
                        } else {
                            AppCard {
                                VStack(alignment: .leading, spacing: 12) {
                                    Chart(samples) { sample in
                                        AreaMark(
                                            x: .value("Time", sample.timestamp),
                                            y: .value("Value", sample.value)
                                        )
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [
                                                    AppPalette.accent.opacity(0.45),
                                                    AppPalette.accent.opacity(0.08)
                                                ],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )

                                        LineMark(
                                            x: .value("Time", sample.timestamp),
                                            y: .value("Value", sample.value)
                                        )
                                        .lineStyle(StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round))
                                        .interpolationMethod(.catmullRom)
                                        .foregroundStyle(AppPalette.accent)
                                    }
                                    .frame(height: 240)
                                    .chartXAxis {
                                        AxisMarks(values: .stride(by: .hour, count: 3)) { _ in
                                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.6))
                                                .foregroundStyle(.white.opacity(0.18))
                                            AxisTick()
                                                .foregroundStyle(.white.opacity(0.38))
                                            AxisValueLabel(
                                                format: .dateTime.hour(.twoDigits(amPM: .omitted)),
                                                centered: true
                                            )
                                            .foregroundStyle(.white.opacity(0.74))
                                        }
                                    }
                                    .chartYAxis {
                                        AxisMarks(position: .leading) { _ in
                                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.6))
                                                .foregroundStyle(.white.opacity(0.15))
                                            AxisTick()
                                                .foregroundStyle(.white.opacity(0.32))
                                            AxisValueLabel()
                                                .foregroundStyle(.white.opacity(0.74))
                                        }
                                    }
                                    .chartPlotStyle { plot in
                                        plot
                                            .background(Color.white.opacity(0.03))
                                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    }

                                    if !unitLabel.isEmpty {
                                        Text("\(loc("单位", "Unit")): \(unitLabel)")
                                            .font(.system(.footnote, design: .rounded, weight: .medium))
                                            .foregroundStyle(.white.opacity(0.68))
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 18)
                    .frame(maxWidth: 960)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle(WeatherFormatter.localizedMetricName(metric.metric, locale: locale))
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
        }
        .presentationDetents([.medium, .large])
    }

    private var isNight: Bool {
        if let sunrise = snapshot.sunrise, let sunset = snapshot.sunset {
            return snapshot.timestamp < sunrise || snapshot.timestamp >= sunset
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: snapshot.timezone) ?? .current
        let hour = calendar.component(.hour, from: snapshot.timestamp)
        return hour < 6 || hour >= 18
    }

    private var unitLabel: String {
        switch metric.metric {
        case .temperature, .feelsLike:
            return resolvedUnitSystem == .imperial ? "°F" : "°C"
        case .humidity, .precipitationProbability:
            return "%"
        case .windSpeed:
            return resolvedUnitSystem == .imperial ? "mph" : "km/h"
        case .windDirection:
            return "°"
        case .pressure:
            return resolvedUnitSystem == .imperial ? "inHg" : "hPa"
        case .visibility:
            return resolvedUnitSystem == .imperial ? "mi" : "km"
        case .uvIndex:
            return loc("指数", "Index")
        default:
            return ""
        }
    }

    private func convertedChartValue(_ value: Double, metric: WeatherMetric) -> Double {
        switch metric {
        case .temperature, .feelsLike:
            return resolvedUnitSystem == .imperial ? value * 9 / 5 + 32 : value
        case .windSpeed:
            return resolvedUnitSystem == .imperial ? value * 0.621371 : value
        case .pressure:
            return resolvedUnitSystem == .imperial ? value * 0.029529983071445 : value
        case .visibility:
            return resolvedUnitSystem == .imperial ? value * 0.621371 : value
        default:
            return value
        }
    }

    private func loc(_ zh: String, _ en: String) -> String {
        WeatherFormatter.prefersChineseSystem(locale) ? zh : en
    }
}

private struct SunlightCard: View {
    let rows: [SunlightRow]
    let locale: Locale

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 14) {
                Text(loc("日光信息", "Sunlight"))
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)

                VStack(spacing: 10) {
                    ForEach(rows) { row in
                        HStack(spacing: 10) {
                            Image(systemName: row.symbol)
                                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.72))
                                .frame(width: 18)

                            Text(row.title)
                                .font(.system(.callout, design: .rounded, weight: .medium))
                                .foregroundStyle(.white.opacity(0.72))

                            Spacer(minLength: 8)

                            Text(row.value)
                                .font(.system(.callout, design: .rounded, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                    }
                }
            }
        }
    }

    private func loc(_ zh: String, _ en: String) -> String {
        WeatherFormatter.prefersChineseSystem(locale) ? zh : en
    }
}

private struct QuickActionsCard: View {
    let onSelectTab: (AppTab) -> Void
    let locale: Locale

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 14) {
                Text(loc("快捷操作", "Quick Actions"))
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)

                VStack(spacing: 10) {
                    QuickActionButton(
                        title: loc("更新位置", "Update Location"),
                        subtitle: loc("同步当前位置，为首页和组件刷新天气", "Sync the current location for the dashboard and widgets"),
                        symbol: "location.fill",
                        action: { onSelectTab(.location) }
                    )

                    QuickActionButton(
                        title: loc("编辑方案", "Edit Profiles"),
                        subtitle: loc("管理小组件字段、顺序和单位组合", "Manage widget metrics, ordering, and unit presets"),
                        symbol: "square.grid.2x2.fill",
                        action: { onSelectTab(.profiles) }
                    )

                    QuickActionButton(
                        title: loc("应用设置", "App Settings"),
                        subtitle: loc("配置 API Key 和调试选项", "Configure the API key and debug options"),
                        symbol: "slider.horizontal.3",
                        action: { onSelectTab(.settings) }
                    )
                }
            }
        }
    }

    private func loc(_ zh: String, _ en: String) -> String {
        WeatherFormatter.prefersChineseSystem(locale) ? zh : en
    }
}

private struct QuickActionButton: View {
    let title: String
    let subtitle: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(Color.white.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(.body, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.white.opacity(0.70))
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(.footnote, design: .rounded, weight: .bold))
                    .foregroundStyle(.white.opacity(0.55))
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct LoadingStateCard: View {
    let locale: Locale

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    ProgressView()
                        .tint(.white)
                    Text(loc("正在载入实时天气...", "Loading live weather..."))
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                }

                Text(loc(
                    "首页会显示当前天气、湿度和关键环境指标。",
                    "The dashboard will show current weather, humidity, and key environmental metrics."
                ))
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.white.opacity(0.72))
            }
        }
    }

    private func loc(_ zh: String, _ en: String) -> String {
        WeatherFormatter.prefersChineseSystem(locale) ? zh : en
    }
}

private struct EmptyLocationCard: View {
    let locale: Locale
    let onOpenLocation: () -> Void

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 12) {
                Label(loc("还没有可用位置", "No Saved Location Yet"), systemImage: "location.slash.fill")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)

                Text(loc(
                    "先在“定位”页保存当前位置，首页才能展示实时天气和关键指标。",
                    "Save your current location in the Location tab before the dashboard can show live weather and key metrics."
                ))
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.white.opacity(0.72))

                Button(loc("前往定位", "Open Location")) {
                    onOpenLocation()
                }
                .buttonStyle(AppPrimaryButtonStyle())
            }
        }
    }

    private func loc(_ zh: String, _ en: String) -> String {
        WeatherFormatter.prefersChineseSystem(locale) ? zh : en
    }
}

private struct ErrorStateCard: View {
    let message: String
    let locale: Locale
    let onRetry: () -> Void
    let onOpenLocation: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 12) {
                Label(loc("天气加载失败", "Weather Failed to Load"), systemImage: "exclamationmark.triangle.fill")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)

                Text(message.isEmpty ? loc("请稍后重试。", "Please try again in a moment.") : message)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.white.opacity(0.78))

                HStack(spacing: 10) {
                    Button(loc("重新加载", "Reload")) {
                        onRetry()
                    }
                    .buttonStyle(AppPrimaryButtonStyle())

                    Button(loc("定位", "Location")) {
                        onOpenLocation()
                    }
                    .buttonStyle(AppSecondaryButtonStyle())

                    Button(loc("设置", "Settings")) {
                        onOpenSettings()
                    }
                    .buttonStyle(AppSecondaryButtonStyle())
                }
            }
        }
    }

    private func loc(_ zh: String, _ en: String) -> String {
        WeatherFormatter.prefersChineseSystem(locale) ? zh : en
    }
}

private struct DashboardMetric: Identifiable {
    let metric: WeatherMetric
    let valueText: String

    var id: WeatherMetric { metric }
}

private struct HourlyChartSample: Identifiable {
    let timestamp: Date
    let value: Double

    var id: Date { timestamp }
}

private struct SunlightRow: Identifiable {
    let symbol: String
    let title: String
    let value: String

    let id = UUID()
}
