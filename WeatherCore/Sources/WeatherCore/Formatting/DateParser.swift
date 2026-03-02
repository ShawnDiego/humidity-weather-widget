import Foundation

enum DateParser {
    static func parseOpenMeteo(_ value: String) -> Date? {
        let withFractional = ISO8601DateFormatter()
        withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let parsed = withFractional.date(from: value) {
            return parsed
        }

        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: value)
    }
}

extension Double {
    init?(_ raw: String?) {
        guard let raw else { return nil }
        self.init(raw)
    }
}
