import Foundation

public actor DisplayProfileStore {
    private let defaults: UserDefaults
    private let storageKey = "display_profiles"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init() {
        self.defaults = SharedContainer.userDefaults()
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    public func fetchProfiles() -> [DisplayProfile] {
        guard let data = defaults.data(forKey: storageKey),
              let profiles = try? decoder.decode([DisplayProfile].self, from: data),
              !profiles.isEmpty
        else {
            let fallback = [DisplayProfile.default]
            persistProfiles(fallback)
            return fallback
        }

        return profiles.map { profile in
            var normalized = profile
            normalized.sanitizeMetrics()
            if normalized.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                normalized.name = WeatherFormatter.localized("未命名方案", "Untitled Profile")
            }
            return normalized
        }
    }

    @discardableResult
    public func ensureDefaultProfile() -> DisplayProfile {
        let profiles = fetchProfiles()
        return profiles.first ?? DisplayProfile.default
    }

    public func saveProfiles(_ profiles: [DisplayProfile]) {
        let normalized = profiles.isEmpty ? [DisplayProfile.default] : profiles.map {
            var profile = $0
            profile.sanitizeMetrics()
            return profile
        }
        persistProfiles(normalized)
    }

    public func upsert(_ profile: DisplayProfile) {
        var profiles = fetchProfiles()
        if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[index] = profile
        } else {
            profiles.append(profile)
        }
        saveProfiles(profiles)
    }

    public func delete(id: UUID) {
        var profiles = fetchProfiles()
        profiles.removeAll { $0.id == id }
        saveProfiles(profiles)
    }

    public func profile(with id: UUID?) -> DisplayProfile {
        let profiles = fetchProfiles()
        guard let id else { return profiles.first ?? DisplayProfile.default }
        return profiles.first(where: { $0.id == id }) ?? profiles.first ?? DisplayProfile.default
    }

    private func persistProfiles(_ profiles: [DisplayProfile]) {
        guard let data = try? encoder.encode(profiles) else { return }
        defaults.set(data, forKey: storageKey)
    }
}
