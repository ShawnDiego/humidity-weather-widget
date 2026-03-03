import Foundation
#if canImport(os)
import os.log
#endif

public struct CompositeWeatherProvider: WeatherProvider {
    private let primary: WeatherProvider?
    private let secondary: WeatherProvider
    #if canImport(os)
    private let logger = Logger(subsystem: AppConfig.appGroup, category: "CompositeWeatherProvider")
    #endif

    public init(primary: WeatherProvider?, secondary: WeatherProvider) {
        self.primary = primary
        self.secondary = secondary
    }

    public func fetchCurrent(lat: Double, lon: Double, tz: String) async throws -> WeatherSnapshot {
        guard let primary else {
            return try await secondary.fetchCurrent(lat: lat, lon: lon, tz: tz)
        }

        let primaryTask = Task {
            try await primary.fetchCurrent(lat: lat, lon: lon, tz: tz)
        }
        let secondaryTask = Task {
            try await secondary.fetchCurrent(lat: lat, lon: lon, tz: tz)
        }

        let primaryResult: Result<WeatherSnapshot, Error>
        let secondaryResult: Result<WeatherSnapshot, Error>

        do {
            primaryResult = .success(try await primaryTask.value)
        } catch {
            primaryResult = .failure(error)
        }

        do {
            secondaryResult = .success(try await secondaryTask.value)
        } catch {
            secondaryResult = .failure(error)
        }

        switch (primaryResult, secondaryResult) {
        case let (.success(primarySnapshot), .success(secondarySnapshot)):
            var merged = primarySnapshot
            let originalCount = merged.values.count
            merged.mergeMissingValues(from: secondarySnapshot)
            if merged.values.count > originalCount {
                merged.source = "\(primarySnapshot.source)+\(secondarySnapshot.source)"
                #if canImport(os)
                logger.debug("Merged \(merged.values.count - originalCount, privacy: .public) missing metric(s) from secondary provider")
                #endif
            }
            return merged
        case let (.success(primarySnapshot), .failure(secondaryError)):
            #if canImport(os)
            logger.warning("Secondary provider failed (non-critical): \(secondaryError.localizedDescription, privacy: .public)")
            #endif
            return primarySnapshot
        case let (.failure(primaryError), .success(secondarySnapshot)):
            #if canImport(os)
            logger.warning("Primary provider failed, falling back to secondary: \(primaryError.localizedDescription, privacy: .public)")
            #endif
            return secondarySnapshot
        case let (.failure(primaryError), .failure(secondaryError)):
            #if canImport(os)
            logger.error("Both providers failed — primary: \(primaryError.localizedDescription, privacy: .public); secondary: \(secondaryError.localizedDescription, privacy: .public)")
            #endif
            throw WeatherError.compositeFailure([primaryError, secondaryError])
        }
    }
}
