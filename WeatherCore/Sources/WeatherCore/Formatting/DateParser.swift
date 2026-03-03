import Foundation

enum DateParser {
    private nonisolated(unsafe) static let isoWithFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private nonisolated(unsafe) static let isoPlain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    /// Cache of `DateFormatter` instances keyed by IANA timezone identifier.
    /// Bounded at 30 entries — far more than the number of distinct timezones
    /// that would be active at once.
    private nonisolated(unsafe) static let localFormatterCache: NSCache<NSString, DateFormatter> = {
        let cache = NSCache<NSString, DateFormatter>()
        cache.countLimit = 30
        return cache
    }()

    /// Parses an Open-Meteo timestamp string.
    ///
    /// The Open-Meteo API returns local-time strings in `"yyyy-MM-dd'T'HH:mm"`
    /// format (no timezone designator) when a timezone is specified in the
    /// request.  Standard ISO-8601 variants with timezone are tried first so
    /// that UTC responses (which do carry a `Z` suffix) are also handled.
    ///
    /// - Parameters:
    ///   - value: The raw timestamp string from the API response.
    ///   - timeZone: The timezone passed to the Open-Meteo request, used to
    ///     correctly interpret local-time strings.  Defaults to UTC.
    static func parseOpenMeteo(_ value: String, timeZone: TimeZone = TimeZone(secondsFromGMT: 0)!) -> Date? {
        if let parsed = isoWithFractional.date(from: value) { return parsed }
        if let parsed = isoPlain.date(from: value) { return parsed }

        // Open-Meteo returns local times as "yyyy-MM-dd'T'HH:mm" (no seconds,
        // no timezone designator) when a timezone is provided in the request.
        let key = NSString(string: timeZone.identifier)
        let formatter: DateFormatter
        if let cached = localFormatterCache.object(forKey: key) {
            formatter = cached
        } else {
            let newFormatter = DateFormatter()
            newFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
            newFormatter.locale = Locale(identifier: "en_US_POSIX")
            newFormatter.timeZone = timeZone
            localFormatterCache.setObject(newFormatter, forKey: key)
            formatter = newFormatter
        }
        return formatter.date(from: value)
    }
}

extension Double {
    init?(_ raw: String?) {
        guard let raw else { return nil }
        self.init(raw)
    }
}
