import Foundation

public struct CompositeWeatherProvider: WeatherProvider {
    private let primary: WeatherProvider?
    private let secondary: WeatherProvider

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
            }
            return merged
        case let (.success(primarySnapshot), .failure):
            return primarySnapshot
        case let (.failure, .success(secondarySnapshot)):
            return secondarySnapshot
        case let (.failure(primaryError), .failure(secondaryError)):
            throw WeatherError.compositeFailure([primaryError, secondaryError])
        }
    }
}
