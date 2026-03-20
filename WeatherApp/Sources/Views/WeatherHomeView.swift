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
                    VStack(alignment: .leading, spacing: 20) {
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
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 14)
                    .padding(.bottom, 28)
                    .frame(maxWidth: 960)
                    .frame(maxWidth: .infinity)
                }
                .refreshable {
                    await model.refreshCurrentWeather(force: true)
                }
            }
            .navigationTitle(locationTitle)
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
            VStack(alignment: .leading, spacing: 10) {
                DashboardSectionHeader(
                    title: loc("关键指标", "Key Metrics"),
                    subtitle: loc("点击任一指标查看 24 小时趋势", "Tap any metric to inspect the 24-hour trend")
                )
                WeatherMetricGridCard(
                    metrics: dashboardMetrics(snapshot),
                    locale: locale,
                    onSelectMetric: { metric in
                        selectedMetric = metric
                    }
                )
            }
        }

        if !sunlightRows(snapshot).isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                DashboardSectionHeader(
                    title: loc("日光信息", "Sunlight"),
                    subtitle: loc("日出、日落和有效日照时长", "Sunrise, sunset, and effective daylight duration")
                )
                SunlightCard(rows: sunlightRows(snapshot))
            }
        }
    }

    private var locationTitle: String {
        if let snapshotName = model.currentSnapshot?.snapshot.locationName,
           !snapshotName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return snapshotName
        }
        if let storedName = model.storedLocation?.name,
           !storedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return storedName
        }
        return loc("天气", "Weather")
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

private struct DashboardSectionHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(.footnote, design: .rounded, weight: .heavy))
                .tracking(0.8)
                .foregroundStyle(.white.opacity(0.84))
            Text(subtitle)
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(.white.opacity(0.62))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }
}

private struct WeatherSourceBadge: View {
    let source: String
    let locale: Locale

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(loc("数据来源", "Data Source"), systemImage: "dot.radiowaves.left.and.right")
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(.white.opacity(0.72))
            Text(source)
                .font(.system(.body, design: .rounded, weight: .semibold))
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.10))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func loc(_ zh: String, _ en: String) -> String {
        WeatherFormatter.prefersChineseSystem(locale) ? zh : en
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
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            theme.conditionAccent.opacity(isNight ? 0.42 : 0.56),
                            Color.white.opacity(0.10),
                            Color.black.opacity(isNight ? 0.36 : 0.24)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(Color.white.opacity(0.20), lineWidth: 1)
                )

            Circle()
                .fill(theme.conditionAccent.opacity(0.34))
                .frame(width: 220, height: 220)
                .blur(radius: 30)
                .offset(x: 74, y: -92)

            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(WeatherFormatter.conditionDescription(for: snapshot.conditionCode, locale: locale))
                            .font(.system(.title3, design: .rounded, weight: .bold))
                            .foregroundStyle(.white)

                        Text(snapshot.locationName)
                            .font(.system(.subheadline, design: .rounded, weight: .medium))
                            .foregroundStyle(.white.opacity(0.82))

                        Text(updatedAtText)
                            .font(.system(.footnote, design: .rounded, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.72))
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
                            size: 60,
                            palette: theme.glyphPalette
                        )
                        .shadow(color: .black.opacity(0.24), radius: 9, x: 0, y: 5)
                    }
                }

                HStack(alignment: .bottom, spacing: 16) {
                    Text(temperatureText)
                        .font(.system(size: 62, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.68)
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

                HStack(spacing: 10) {
                    if let humidityText {
                        HumidityHighlightCard(value: humidityText, accent: theme.conditionAccent, locale: locale)
                    }

                    WeatherSourceBadge(source: snapshot.source, locale: locale)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 18)
        }
        .shadow(color: .black.opacity(0.26), radius: 18, x: 0, y: 10)
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
                .foregroundStyle(.white.opacity(0.74))

            Text(value)
                .font(.system(.title3, design: .rounded, weight: .heavy))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                colors: [
                    accent.opacity(0.42),
                    Color.white.opacity(0.10)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
                .foregroundStyle(.white.opacity(0.74))
            Text(value)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 10)
        .background(accent.opacity(0.30))
        .overlay(
            Capsule(style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
        .clipShape(Capsule(style: .continuous))
    }
}

private struct WeatherMetricGridCard: View {
    let metrics: [DashboardMetric]
    let locale: Locale
    let onSelectMetric: (DashboardMetric) -> Void

    private var metricRows: [[DashboardMetric]] {
        stride(from: 0, to: metrics.count, by: 2).map { index in
            Array(metrics[index ..< min(index + 2, metrics.count)])
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            ForEach(Array(metricRows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 10) {
                    WeatherMetricTile(
                        metric: row[0],
                        locale: locale,
                        action: { onSelectMetric(row[0]) }
                    )

                    if row.count > 1 {
                        WeatherMetricTile(
                            metric: row[1],
                            locale: locale,
                            action: { onSelectMetric(row[1]) }
                        )
                    } else {
                        WeatherMetricTile(
                            metric: row[0],
                            locale: locale,
                            action: nil
                        )
                        .hidden()
                        .accessibilityHidden(true)
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.10),
                            Color.white.opacity(0.04)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
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
        HStack(spacing: 10) {
            Image(systemName: WeatherFormatter.metricSymbol(for: metric.metric))
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(.white.opacity(0.90))
                .frame(width: 26, height: 26)
                .background(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.20),
                            Color.white.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(WeatherFormatter.localizedMetricName(metric.metric, locale: locale))
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.76))
                    .lineLimit(1)
                Text(metric.valueText)
                    .font(.system(.body, design: .rounded, weight: .heavy))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .contentTransition(.numericText())
            }

            if action != nil {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(.white.opacity(0.62))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 78, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.16),
                            Color.white.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct HourlyMetricChartSheet: View {
    let metric: DashboardMetric
    let snapshot: WeatherSnapshot
    let unitSystem: UnitSystem
    let locale: Locale
    @State private var selectedTimestamp: Date?
    @State private var selectedDayIndex: Int = 0
    @State private var hasInitializedDaySelection = false

    private var allSamples: [HourlyChartSample] {
        snapshot.hourly
            .sorted { $0.timestamp < $1.timestamp }
            .compactMap { point in
                guard let rawValue = point.values[metric.metric] else { return nil }
                return HourlyChartSample(
                    timestamp: point.timestamp,
                    rawValue: rawValue,
                    plottedValue: convertedChartValue(rawValue, metric: metric.metric)
                )
            }
    }

    private var dayCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: snapshot.timezone) ?? .current
        return calendar
    }

    private var dailySeries: [HourlyDaySeries] {
        let todayStart = dayCalendar.startOfDay(for: snapshot.timestamp)
        let tenDayUpperBound = dayCalendar.date(byAdding: .day, value: 10, to: todayStart) ?? todayStart.addingTimeInterval(10 * 24 * 3600)
        let futureSamples = allSamples.filter { sample in
            sample.timestamp >= todayStart && sample.timestamp < tenDayUpperBound
        }
        let source = futureSamples.isEmpty ? allSamples : futureSamples

        let grouped = Dictionary(grouping: source) { sample in
            dayCalendar.startOfDay(for: sample.timestamp)
        }

        return grouped.keys.sorted().prefix(10).map { dayStart in
            HourlyDaySeries(
                dayStart: dayStart,
                samples: grouped[dayStart, default: []].sorted { $0.timestamp < $1.timestamp }
            )
        }
    }

    private var currentDaySamples: [HourlyChartSample] {
        guard dailySeries.indices.contains(selectedDayIndex) else { return [] }
        return dailySeries[selectedDayIndex].samples
    }

    private var resolvedUnitSystem: UnitSystem {
        WeatherFormatter.effectiveUnitSystem(unitSystem, locale: locale)
    }

    private var selectedSample: HourlyChartSample? {
        guard let selectedTimestamp else { return nil }
        return currentDaySamples.min { lhs, rhs in
            abs(lhs.timestamp.timeIntervalSince(selectedTimestamp)) <
            abs(rhs.timestamp.timeIntervalSince(selectedTimestamp))
        }
    }

    private var focusSample: HourlyChartSample? {
        selectedSample ?? currentDaySamples.first
    }

    private var canShowPreviousDay: Bool {
        selectedDayIndex > 0
    }

    private var canShowNextDay: Bool {
        selectedDayIndex < dailySeries.count - 1
    }

    private var currentDayLabel: String {
        guard dailySeries.indices.contains(selectedDayIndex) else {
            return loc("暂无日期", "No date")
        }

        return dailySeries[selectedDayIndex].dayStart.formatted(
            .dateTime.weekday(.abbreviated).month(.abbreviated).day()
        )
    }

    private var dayCounterLabel: String {
        guard !dailySeries.isEmpty else { return "" }
        return "\(selectedDayIndex + 1)/\(dailySeries.count)"
    }

    private var trendSubtitle: String {
        let count = max(1, dailySeries.count)
        return WeatherFormatter.prefersChineseSystem(locale)
            ? "未来\(count)天逐小时趋势"
            : "Hourly trend for the next \(count) days"
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
                        if dailySeries.isEmpty {
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
                                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(WeatherFormatter.localizedMetricName(metric.metric, locale: locale))
                                                .font(.system(.title3, design: .rounded, weight: .bold))
                                                .foregroundStyle(.white)
                                            Text(trendSubtitle)
                                                .font(.system(.subheadline, design: .rounded))
                                                .foregroundStyle(.white.opacity(0.72))
                                        }

                                        Spacer(minLength: 8)

                                        Text(dayCounterLabel)
                                            .font(.system(.footnote, design: .rounded, weight: .semibold))
                                            .foregroundStyle(.white.opacity(0.72))
                                    }

                                    HStack(spacing: 12) {
                                        Button {
                                            showPreviousDay()
                                        } label: {
                                            Image(systemName: "chevron.left")
                                                .font(.system(.callout, design: .rounded, weight: .bold))
                                                .foregroundStyle(canShowPreviousDay ? .white : .white.opacity(0.42))
                                        }
                                        .buttonStyle(.plain)
                                        .disabled(!canShowPreviousDay)

                                        Spacer(minLength: 8)

                                        Text(currentDayLabel)
                                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                            .foregroundStyle(.white.opacity(0.86))
                                            .lineLimit(1)

                                        Spacer(minLength: 8)

                                        Button {
                                            showNextDay()
                                        } label: {
                                            Image(systemName: "chevron.right")
                                                .font(.system(.callout, design: .rounded, weight: .bold))
                                                .foregroundStyle(canShowNextDay ? .white : .white.opacity(0.42))
                                        }
                                        .buttonStyle(.plain)
                                        .disabled(!canShowNextDay)
                                    }
                                    .padding(.horizontal, 2)

                                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                                        Text(displayedMetricText)
                                            .font(.system(.title2, design: .rounded, weight: .bold))
                                            .foregroundStyle(.white)

                                        if let focusSample {
                                            Text("\(loc("时间", "Time")): \(focusSample.timestamp.formatted(date: .omitted, time: .shortened))")
                                                .font(.system(.footnote, design: .rounded, weight: .medium))
                                                .foregroundStyle(.white.opacity(0.70))
                                                .lineLimit(1)
                                        } else {
                                            Text(loc("拖动图表查看每小时数值", "Drag on the chart to inspect hourly values"))
                                                .font(.system(.footnote, design: .rounded, weight: .medium))
                                                .foregroundStyle(.white.opacity(0.70))
                                        }

                                        Spacer(minLength: 8)

                                        if !unitLabel.isEmpty {
                                            Text(unitLabel)
                                                .font(.system(.footnote, design: .rounded, weight: .medium))
                                                .foregroundStyle(.white.opacity(0.68))
                                        }
                                    }

                                    Chart(currentDaySamples) { sample in
                                        AreaMark(
                                            x: .value("Time", sample.timestamp),
                                            y: .value("Value", sample.plottedValue)
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
                                            y: .value("Value", sample.plottedValue)
                                        )
                                        .lineStyle(StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round))
                                        .interpolationMethod(.catmullRom)
                                        .foregroundStyle(AppPalette.accent)

                                        if let selectedSample {
                                            RuleMark(x: .value("Selected Time", selectedSample.timestamp))
                                                .lineStyle(StrokeStyle(lineWidth: 1.1, dash: [4, 3]))
                                                .foregroundStyle(.white.opacity(0.58))

                                            PointMark(
                                                x: .value("Selected Time", selectedSample.timestamp),
                                                y: .value("Selected Value", selectedSample.plottedValue)
                                            )
                                            .symbolSize(80)
                                            .foregroundStyle(.white)
                                        }
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
                                    .chartXSelection(value: $selectedTimestamp)
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
        .onAppear {
            initializeDaySelectionIfNeeded()
            clampSelectedDayIndex()
        }
        .onChange(of: dailySeries.count) { _, _ in
            clampSelectedDayIndex()
            initializeDaySelectionIfNeeded()
        }
        .onChange(of: selectedDayIndex) { _, _ in
            selectedTimestamp = nil
        }
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

    private var displayedMetricText: String {
        if let focusSample {
            return WeatherFormatter.formattedValue(
                metric: metric.metric,
                value: focusSample.rawValue,
                unitSystem: unitSystem,
                locale: locale
            )
        }
        return metric.valueText
    }

    private func showPreviousDay() {
        guard canShowPreviousDay else { return }
        selectedDayIndex -= 1
    }

    private func showNextDay() {
        guard canShowNextDay else { return }
        selectedDayIndex += 1
    }

    private func initializeDaySelectionIfNeeded() {
        guard !hasInitializedDaySelection else { return }
        guard !dailySeries.isEmpty else { return }

        if let currentDayIndex = dailySeries.firstIndex(where: { series in
            dayCalendar.isDate(series.dayStart, inSameDayAs: snapshot.timestamp)
        }) {
            selectedDayIndex = currentDayIndex
        } else {
            selectedDayIndex = 0
        }

        hasInitializedDaySelection = true
    }

    private func clampSelectedDayIndex() {
        guard !dailySeries.isEmpty else {
            selectedDayIndex = 0
            return
        }

        selectedDayIndex = min(max(0, selectedDayIndex), dailySeries.count - 1)
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

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(rows) { row in
                    VStack(alignment: .leading, spacing: 6) {
                        Label(row.title, systemImage: row.symbol)
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.74))
                        Text(row.value)
                            .font(.system(.headline, design: .rounded, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .frame(minWidth: 122, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.14),
                                        Color.white.opacity(0.05)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.16), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        }
        .safeAreaPadding(.horizontal, 0)
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
    let rawValue: Double
    let plottedValue: Double

    var id: Date { timestamp }
}

private struct HourlyDaySeries {
    let dayStart: Date
    let samples: [HourlyChartSample]
}

private struct SunlightRow: Identifiable {
    let symbol: String
    let title: String
    let value: String

    let id = UUID()
}
