import AppIntents
import WidgetKit

/// Configuration intent surfaced by long-pressing → Edit Widget. Lets users
/// pin a specific palette per widget instance and toggle the time overlay.
struct MandazaWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Mandaza Widget"
    static var description = IntentDescription("Pick a palette and rotation cadence for this widget.")

    @Parameter(title: "Palette", default: .followsApp)
    var palette: PaletteOption

    @Parameter(title: "Auto-rotate", default: true)
    var autoRotate: Bool

    @Parameter(title: "Rotation Interval", default: .hourly)
    var interval: RotationInterval

    @Parameter(title: "Show Time", default: true)
    var showTime: Bool

    init() {}
}

enum PaletteOption: String, AppEnum {
    case followsApp, aurora, sunset, ember, bioluminescent
    // `arctic` is the legacy raw value for what is now the "Canopy" palette.
    // The case is kept (and only the display name updated) so widget configs
    // saved by older builds still decode instead of resetting to the default.
    // resolved() returns "arctic", which Palette.by(id:) maps to canopy.
    case vaporwave, cyberpunk, risograph, oxblood, arctic, dichromat, amber, terrain

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Palette")
    static var caseDisplayRepresentations: [PaletteOption: DisplayRepresentation] = [
        .followsApp:      "Follows App",
        .aurora:          "Aurora",
        .sunset:          "Sunset",
        .ember:           "Ember",
        .bioluminescent:  "Bioluminescent",
        .vaporwave:       "Vaporwave",
        .cyberpunk:       "Cyberpunk",
        .risograph:       "Risograph",
        .oxblood:         "Oxblood",
        .arctic:          "Canopy",
        .dichromat:       "Dichromat",
        .amber:           "Amber",
        .terrain:         "Terrain"
    ]

    /// Resolved palette id given the user's app default.
    @MainActor
    func resolved() -> String {
        switch self {
        case .followsApp: return MandazaSettings.shared.paletteId
        default:          return rawValue
        }
    }
}

enum RotationInterval: String, AppEnum {
    case quarterHourly, hourly, sixHourly, daily

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Rotation")
    static var caseDisplayRepresentations: [RotationInterval: DisplayRepresentation] = [
        .quarterHourly: "Every 15 minutes",
        .hourly:        "Every hour",
        .sixHourly:     "Every 6 hours",
        .daily:         "Once a day"
    ]

    var minutes: Int {
        switch self {
        case .quarterHourly: return 15
        case .hourly:        return 60
        case .sixHourly:     return 360
        case .daily:         return 1440
        }
    }
}
