import Foundation

public actor LocationStore {
    private let defaults: UserDefaults
    private let storageKey = "latest_device_location"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init() {
        self.defaults = SharedContainer.userDefaults()
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    public func save(_ location: StoredLocation) {
        guard let data = try? encoder.encode(location) else { return }
        defaults.set(data, forKey: storageKey)
    }

    public func load() -> StoredLocation? {
        guard let data = defaults.data(forKey: storageKey),
              let location = try? decoder.decode(StoredLocation.self, from: data)
        else {
            return nil
        }
        return location
    }
}
