import SwiftUI
import WeatherCore

struct ProfileListView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.locale) private var locale
    @State private var editorDraft: DisplayProfile?
    @State private var showingCreate = false

    let highlightProfileID: UUID?

    var body: some View {
        NavigationStack {
            ZStack {
                AppGradientBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        AppSectionHeader(
                            title: loc("显示方案", "Display Profiles"),
                            subtitle: loc(
                                "为不同小组件实例创建独立字段组合与单位设置",
                                "Create independent metric sets and unit rules for each widget"
                            )
                        )

                        if model.profiles.isEmpty {
                            AppCard {
                                VStack(alignment: .leading, spacing: 10) {
                                    Label(loc("还没有方案", "No Profiles Yet"), systemImage: "square.grid.2x2")
                                        .font(.system(.headline, design: .rounded, weight: .bold))
                                        .foregroundStyle(.white)
                                    Text(loc(
                                        "点击右上角 + 创建你的第一个天气显示方案。",
                                        "Tap + in the top-right to create your first weather display profile."
                                    ))
                                        .font(.system(.subheadline, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.72))
                                }
                            }
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(model.profiles) { profile in
                                    ProfileCard(
                                        profile: profile,
                                        isHighlighted: highlightProfileID == profile.id,
                                        onEdit: { editorDraft = profile },
                                        onDelete: {
                                            Task {
                                                await model.deleteProfile(id: profile.id)
                                            }
                                        }
                                    )
                                }
                            }
                            .animation(.spring(response: 0.3, dampingFraction: 0.84), value: model.profiles)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 18)
                    .padding(.bottom, 26)
                    .frame(maxWidth: 960)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle(loc("方案", "Profiles"))
            .toolbar {
#if os(iOS)
                ToolbarItem(placement: .topBarTrailing) {
                    addButton
                }
#else
                ToolbarItem(placement: .primaryAction) {
                    addButton
                }
#endif
            }
            .sheet(isPresented: $showingCreate) {
                editorSheet(profile: nil) { profile in
                    Task {
                        await model.upsertProfile(profile)
                        showingCreate = false
                    }
                }
            }
            .sheet(item: $editorDraft) { profile in
                editorSheet(profile: profile) { updated in
                    Task {
                        await model.upsertProfile(updated)
                        editorDraft = nil
                    }
                }
            }
        }
    }

    private var addButton: some View {
        Button {
            showingCreate = true
        } label: {
            Image(systemName: "plus")
                .font(.system(.body, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(Color.white.opacity(0.12))
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.20), lineWidth: 1)
                )
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private func loc(_ zh: String, _ en: String) -> String {
        WeatherFormatter.prefersChineseSystem(locale) ? zh : en
    }

    @ViewBuilder
    private func editorSheet(profile: DisplayProfile?, onSave: @escaping (DisplayProfile) -> Void) -> some View {
        NavigationStack {
            ProfileEditorView(profile: profile, onSave: onSave)
        }
#if os(macOS)
        .frame(minWidth: 560, minHeight: 620)
#else
        .presentationDetents([.medium, .large])
#endif
    }
}

private struct ProfileCard: View {
    @Environment(\.locale) private var locale

    let profile: DisplayProfile
    let isHighlighted: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 8) {
                    Label(profile.name, systemImage: "square.grid.2x2.fill")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)

                    if isHighlighted {
                        StatusBadge(text: loc("已关联组件", "Linked to Widget"), tone: .good)
                    }

                    Spacer()

                    StatusBadge(
                        text: WeatherFormatter.localizedUnitSystemName(profile.unitSystem, locale: uiLocale),
                        tone: .neutral
                    )
                }

                WrappingFlowLayout(horizontalSpacing: 10, verticalSpacing: 10) {
                    ForEach(profile.metrics, id: \.self) { metric in
                        MetricChip(
                            title: WeatherFormatter.localizedMetricName(metric, locale: uiLocale),
                            symbol: WeatherFormatter.metricSymbol(for: metric)
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 10) {
                    Button(loc("编辑", "Edit")) {
                        onEdit()
                    }
                    .buttonStyle(AppSecondaryButtonStyle())

                    Button(loc("删除", "Delete"), role: .destructive) {
                        onDelete()
                    }
                    .buttonStyle(AppSecondaryButtonStyle())
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isHighlighted ? AppPalette.accent.opacity(0.85) : .clear, lineWidth: 1.5)
        )
    }

    private func loc(_ zh: String, _ en: String) -> String {
        WeatherFormatter.prefersChineseSystem(locale) ? zh : en
    }

    private var uiLocale: Locale {
        Locale(identifier: Locale.preferredLanguages.first ?? locale.identifier)
    }
}

private struct ProfileEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    let profile: DisplayProfile?
    let onSave: (DisplayProfile) -> Void

    @State private var name: String
    @State private var unitSystem: UnitSystem
    @State private var orderedMetrics: [WeatherMetric]
    @State private var selectedMetrics: Set<WeatherMetric>

    init(profile: DisplayProfile?, onSave: @escaping (DisplayProfile) -> Void) {
        self.profile = profile
        self.onSave = onSave

        let template = profile ?? .default
        _name = State(initialValue: profile?.name ?? "")
        _unitSystem = State(initialValue: template.unitSystem)
        _orderedMetrics = State(initialValue: Self.makeOrderedMetrics(from: template.metrics))
        _selectedMetrics = State(initialValue: Set(template.metrics))
    }

    var body: some View {
        Form {
            Section(loc("基本设置", "Basic Settings")) {
                TextField(loc("方案名称", "Profile Name"), text: $name)
                Picker(loc("单位", "Units"), selection: $unitSystem) {
                    Text(WeatherFormatter.localizedUnitSystemName(.auto, locale: uiLocale)).tag(UnitSystem.auto)
                    Text(WeatherFormatter.localizedUnitSystemName(.metric, locale: uiLocale)).tag(UnitSystem.metric)
                    Text(WeatherFormatter.localizedUnitSystemName(.imperial, locale: uiLocale)).tag(UnitSystem.imperial)
                }
            }

            Section(loc("显示字段（点选启用，拖动排序）", "Visible Metrics (tap to toggle, drag to reorder)")) {
                ForEach(orderedMetrics, id: \.self) { metric in
                    HStack {
                        Image(systemName: selectedMetrics.contains(metric) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selectedMetrics.contains(metric) ? AppPalette.accent : .secondary)
                        Image(systemName: WeatherFormatter.metricSymbol(for: metric))
                            .foregroundStyle(.secondary)
                        Text(WeatherFormatter.localizedMetricName(metric, locale: uiLocale))
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        toggle(metric)
                    }
                }
                .onMove { source, destination in
                    orderedMetrics.move(fromOffsets: source, toOffset: destination)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(profile == nil ? loc("新建方案", "New Profile") : loc("编辑方案", "Edit Profile"))
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(loc("取消", "Cancel")) {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(loc("保存", "Save")) {
                    save()
                }
            }
#if os(iOS)
            ToolbarItem(placement: .topBarLeading) {
                EditButton()
            }
#endif
        }
    }

    private static func makeOrderedMetrics(from selected: [WeatherMetric]) -> [WeatherMetric] {
        let selectedSet = Set(selected)
        let rest = WeatherMetric.allCases.filter { !selectedSet.contains($0) }
        return selected + rest
    }

    private func toggle(_ metric: WeatherMetric) {
        if selectedMetrics.contains(metric) {
            selectedMetrics.remove(metric)
        } else {
            selectedMetrics.insert(metric)
        }
    }

    private func save() {
        let selectedOrdered = orderedMetrics.filter { selectedMetrics.contains($0) }
        let finalMetrics = selectedOrdered.isEmpty ? [.temperature] : selectedOrdered

        let profile = DisplayProfile(
            id: profile?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? defaultProfileName : name,
            metrics: finalMetrics,
            unitSystem: unitSystem
        )
        onSave(profile)
        dismiss()
    }

    private var defaultProfileName: String {
        loc("未命名方案", "Untitled Profile")
    }

    private func loc(_ zh: String, _ en: String) -> String {
        WeatherFormatter.prefersChineseSystem(locale) ? zh : en
    }

    private var uiLocale: Locale {
        Locale(identifier: Locale.preferredLanguages.first ?? locale.identifier)
    }
}
