import SwiftUI
import WeatherCore

struct ProfileListView: View {
    @EnvironmentObject private var model: AppModel
    @State private var editorDraft: DisplayProfile?
    @State private var showingCreate = false

    let highlightProfileID: UUID?

    var body: some View {
        NavigationStack {
            List {
                ForEach(model.profiles) { profile in
                    Button {
                        editorDraft = profile
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(profile.name)
                                    .font(.headline)
                                Text(profile.metrics.map(\.displayName).joined(separator: " · "))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 4)
                        .listRowBackground(highlightProfileID == profile.id ? Color.yellow.opacity(0.15) : Color.clear)
                    }
                    .buttonStyle(.plain)
                }
                .onDelete { offsets in
                    for index in offsets {
                        let profile = model.profiles[index]
                        Task {
                            await model.deleteProfile(id: profile.id)
                        }
                    }
                }
            }
            .navigationTitle("显示方案")
            .toolbar {
#if os(iOS)
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingCreate = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
#else
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingCreate = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
#endif
            }
            .sheet(isPresented: $showingCreate) {
                NavigationStack {
                    ProfileEditorView(profile: nil) { profile in
                        Task {
                            await model.upsertProfile(profile)
                            showingCreate = false
                        }
                    }
                }
            }
            .sheet(item: $editorDraft) { profile in
                NavigationStack {
                    ProfileEditorView(profile: profile) { updated in
                        Task {
                            await model.upsertProfile(updated)
                            editorDraft = nil
                        }
                    }
                }
            }
        }
    }
}

private struct ProfileEditorView: View {
    @Environment(\.dismiss) private var dismiss

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
        List {
            Section("基本设置") {
                TextField("方案名称", text: $name)
                Picker("单位", selection: $unitSystem) {
                    Text("自动").tag(UnitSystem.auto)
                    Text("公制").tag(UnitSystem.metric)
                    Text("英制").tag(UnitSystem.imperial)
                }
            }

            Section("显示字段（点选启用，拖动排序）") {
                ForEach(orderedMetrics, id: \.self) { metric in
                    HStack {
                        Image(systemName: selectedMetrics.contains(metric) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selectedMetrics.contains(metric) ? .blue : .secondary)
                        Text(metric.displayName)
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
        .navigationTitle(profile == nil ? "新建方案" : "编辑方案")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
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
            name: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "未命名方案" : name,
            metrics: finalMetrics,
            unitSystem: unitSystem
        )
        onSave(profile)
        dismiss()
    }
}
