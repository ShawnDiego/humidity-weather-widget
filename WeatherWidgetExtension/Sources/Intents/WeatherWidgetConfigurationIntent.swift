import AppIntents
import Foundation
import WeatherCore

struct ProfileEntity: AppEntity, Identifiable {
    let id: String
    let name: String

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "显示方案 / Display Profile")
    static let defaultQuery = ProfileEntityQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: LocalizedStringResource(stringLiteral: name))
    }
}

struct ProfileEntityQuery: EntityQuery {
    func entities(for identifiers: [ProfileEntity.ID]) async throws -> [ProfileEntity] {
        let store = DisplayProfileStore()
        let profiles = await store.fetchProfiles()
        let set = Set(identifiers)
        return profiles
            .filter { set.contains($0.id.uuidString) }
            .map { ProfileEntity(id: $0.id.uuidString, name: $0.name) }
    }

    func suggestedEntities() async throws -> [ProfileEntity] {
        let store = DisplayProfileStore()
        let profiles = await store.fetchProfiles()
        return profiles.map { ProfileEntity(id: $0.id.uuidString, name: $0.name) }
    }

    func defaultResult() async -> ProfileEntity? {
        let store = DisplayProfileStore()
        let defaultProfile = await store.ensureDefaultProfile()
        return ProfileEntity(id: defaultProfile.id.uuidString, name: defaultProfile.name)
    }
}

enum LocationModeIntent: String, AppEnum {
    case current
    case manualCity

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "位置模式 / Location Mode")

    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .current: DisplayRepresentation(title: "当前位置 / Current Location"),
        .manualCity: DisplayRepresentation(title: "手动城市 / Manual City")
    ]
}

struct WeatherWidgetConfigurationIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "天气组件配置 / Weather Widget Configuration"
    static let description = IntentDescription("配置显示方案与位置模式 / Configure profile and location mode")

    @Parameter(title: "显示方案 / Display Profile")
    var profile: ProfileEntity?

    @Parameter(title: "位置模式 / Location Mode", default: .current)
    var locationMode: LocationModeIntent

    @Parameter(title: "手动城市 / Manual City")
    var manualCity: String?

    static var parameterSummary: some ParameterSummary {
        Summary("\(\.$profile) · \(\.$locationMode) · \(\.$manualCity)")
    }
}

extension WeatherWidgetConfigurationIntent {
    static var sample: WeatherWidgetConfigurationIntent {
        WeatherWidgetConfigurationIntent()
    }

    var resolvedProfileID: UUID? {
        guard let raw = profile?.id else { return nil }
        return UUID(uuidString: raw)
    }

    var resolvedLocationMode: LocationMode {
        switch locationMode {
        case .current:
            return .current
        case .manualCity:
            return .manualCity
        }
    }
}
