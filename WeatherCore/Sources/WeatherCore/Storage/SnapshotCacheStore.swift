import Foundation
import CryptoKit

public struct CachedSnapshotEnvelope: Codable, Sendable {
    public var fetchedAt: Date
    public var snapshot: WeatherSnapshot

    public init(fetchedAt: Date, snapshot: WeatherSnapshot) {
        self.fetchedAt = fetchedAt
        self.snapshot = snapshot
    }

    public var age: TimeInterval {
        Date().timeIntervalSince(fetchedAt)
    }
}

public actor SnapshotCacheStore {
    private let cacheDirectory: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(cacheDirectory: URL = SharedContainer.cacheDirectory()) {
        self.cacheDirectory = cacheDirectory
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    public func load(key: String) -> CachedSnapshotEnvelope? {
        let url = fileURL(for: key)
        guard let data = try? Data(contentsOf: url),
              let envelope = try? decoder.decode(CachedSnapshotEnvelope.self, from: data)
        else {
            return nil
        }
        return envelope
    }

    public func save(snapshot: WeatherSnapshot, key: String, at date: Date = Date()) {
        let envelope = CachedSnapshotEnvelope(fetchedAt: date, snapshot: snapshot)
        guard let data = try? encoder.encode(envelope) else { return }
        let url = fileURL(for: key)
        try? data.write(to: url, options: [.atomic])
    }

    public func remove(key: String) {
        try? FileManager.default.removeItem(at: fileURL(for: key))
    }

    public func clearAll() {
        guard let entries = try? FileManager.default.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil) else {
            return
        }
        for url in entries {
            try? FileManager.default.removeItem(at: url)
        }
    }

    public func freshness(for key: String, now: Date = Date(), ttl: TimeInterval = AppConfig.cacheTTL, staleWindow: TimeInterval = AppConfig.staleWindow) -> SnapshotResult? {
        guard let envelope = load(key: key) else { return nil }
        let age = now.timeIntervalSince(envelope.fetchedAt)
        if age <= ttl {
            return SnapshotResult(snapshot: envelope.snapshot, freshness: .live)
        }
        if age <= staleWindow {
            return SnapshotResult(snapshot: envelope.snapshot, freshness: .stale)
        }
        return nil
    }

    private func fileURL(for key: String) -> URL {
        let digest = SHA256.hash(data: Data(key.utf8)).compactMap { String(format: "%02x", $0) }.joined()
        return cacheDirectory.appendingPathComponent("\(digest).json")
    }
}
