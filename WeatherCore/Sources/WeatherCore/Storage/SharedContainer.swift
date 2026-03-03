import Foundation

public enum SharedContainer {
    public static func userDefaults() -> UserDefaults {
        if let shared = UserDefaults(suiteName: AppConfig.appGroup) {
            return shared
        }
        return .standard
    }

    public static func sharedDirectory() -> URL {
        #if !os(Linux)
        if let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppConfig.appGroup) {
            return container
        }
        #endif
        return FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
    }

    public static func cacheDirectory() -> URL {
        let dir = sharedDirectory().appendingPathComponent("WeatherCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
