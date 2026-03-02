import Foundation

public actor WidgetConfigStore {
    private let defaults: UserDefaults
    private let storageKey = "widget_instance_configs"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init() {
        self.defaults = SharedContainer.userDefaults()
    }

    public func config(for widgetID: String) -> WidgetInstanceConfig? {
        loadAll()[widgetID]
    }

    public func save(config: WidgetInstanceConfig, for widgetID: String) {
        var all = loadAll()
        all[widgetID] = config
        persist(all)
    }

    public func removeConfig(for widgetID: String) {
        var all = loadAll()
        all.removeValue(forKey: widgetID)
        persist(all)
    }

    private func loadAll() -> [String: WidgetInstanceConfig] {
        guard let data = defaults.data(forKey: storageKey),
              let map = try? decoder.decode([String: WidgetInstanceConfig].self, from: data)
        else {
            return [:]
        }
        return map
    }

    private func persist(_ map: [String: WidgetInstanceConfig]) {
        guard let data = try? encoder.encode(map) else { return }
        defaults.set(data, forKey: storageKey)
    }
}
