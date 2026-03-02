import Foundation

public actor WeatherRepository {
    private let provider: WeatherProvider
    private let cacheStore: SnapshotCacheStore
    private let ttl: TimeInterval
    private let staleWindow: TimeInterval

    public init(
        provider: WeatherProvider,
        cacheStore: SnapshotCacheStore = SnapshotCacheStore(),
        ttl: TimeInterval = AppConfig.cacheTTL,
        staleWindow: TimeInterval = AppConfig.staleWindow
    ) {
        self.provider = provider
        self.cacheStore = cacheStore
        self.ttl = ttl
        self.staleWindow = staleWindow
    }

    public func fetchSnapshot(for location: ResolvedLocation, now: Date = Date()) async throws -> SnapshotResult {
        let key = Self.cacheKey(for: location)

        do {
            var live = try await provider.fetchCurrent(
                lat: location.latitude,
                lon: location.longitude,
                tz: location.timezone
            )
            live.locationName = location.name
            live.timezone = location.timezone

            if let cached = await cacheStore.load(key: key) {
                live.mergeMissingValues(from: cached.snapshot)
            }

            await cacheStore.save(snapshot: live, key: key, at: now)
            return SnapshotResult(snapshot: live, freshness: .live)
        } catch {
            guard let cached = await cacheStore.freshness(
                for: key,
                now: now,
                ttl: ttl,
                staleWindow: staleWindow
            ) else {
                throw error
            }

            var snapshot = cached.snapshot
            snapshot.locationName = location.name
            snapshot.timezone = location.timezone
            return SnapshotResult(snapshot: snapshot, freshness: cached.freshness)
        }
    }

    public static func cacheKey(for location: ResolvedLocation) -> String {
        let lat = String(format: "%.4f", location.latitude)
        let lon = String(format: "%.4f", location.longitude)
        return "\(lat),\(lon),\(location.timezone)"
    }
}
