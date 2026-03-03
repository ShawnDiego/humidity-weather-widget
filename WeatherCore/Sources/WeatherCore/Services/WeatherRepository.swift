import Foundation
#if canImport(os)
import os.log
#endif

public actor WeatherRepository {
    private let provider: WeatherProvider
    private let cacheStore: SnapshotCacheStore
    private let ttl: TimeInterval
    private let staleWindow: TimeInterval
    #if canImport(os)
    private let logger = Logger(subsystem: AppConfig.appGroup, category: "WeatherRepository")
    #endif

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
            #if canImport(os)
            logger.debug("Fetched live snapshot for \(location.name, privacy: .public) via \(live.source, privacy: .public)")
            #endif
            return SnapshotResult(snapshot: live, freshness: .live)
        } catch {
            #if canImport(os)
            logger.warning("Live fetch failed for \(location.name, privacy: .public): \(error.localizedDescription, privacy: .public)")
            #endif
            guard let cached = await cacheStore.freshness(
                for: key,
                now: now,
                ttl: ttl,
                staleWindow: staleWindow
            ) else {
                #if canImport(os)
                logger.error("No usable cache for \(location.name, privacy: .public); propagating error")
                #endif
                throw error
            }

            #if canImport(os)
            logger.info("Serving \(cached.freshness == .stale ? "stale" : "live", privacy: .public) cached snapshot for \(location.name, privacy: .public)")
            #endif
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
