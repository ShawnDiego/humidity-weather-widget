import Foundation

enum DateParser {
    static func parseOpenMeteo(_ value: String, timeZoneIdentifier: String? = nil) -> Date? {
        let withFractional = ISO8601DateFormatter()
        withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let parsed = withFractional.date(from: value) {
            return parsed
        }

        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        if let parsed = plain.date(from: value) {
            return parsed
        }

        let localFormatter = DateFormatter()
        localFormatter.locale = Locale(identifier: "en_US_POSIX")
        localFormatter.timeZone = timeZoneIdentifier.flatMap(TimeZone.init(identifier:)) ?? .current

        localFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        if let parsed = localFormatter.date(from: value) {
            return parsed
        }

        localFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        return localFormatter.date(from: value)
    }
}

extension Double {
    init?(_ raw: String?) {
        guard let raw else { return nil }
        self.init(raw)
    }
}
