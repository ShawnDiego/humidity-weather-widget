import Foundation

public struct CompositeCityGeocoder: CityGeocoder {
    private let primary: CityGeocoder?
    private let secondary: CityGeocoder

    public init(primary: CityGeocoder?, secondary: CityGeocoder) {
        self.primary = primary
        self.secondary = secondary
    }

    public func resolveCity(_ name: String) async throws -> (name: String, lat: Double, lon: Double, tz: String) {
        if let primary {
            do {
                return try await primary.resolveCity(name)
            } catch {
                return try await secondary.resolveCity(name)
            }
        }
        return try await secondary.resolveCity(name)
    }
}
