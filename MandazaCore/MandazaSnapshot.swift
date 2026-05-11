import Foundation
import CoreGraphics

/// Value-type record of one generated mandala. Used as the unit of
/// • the widget timeline entry,
/// • the app's "favorites" list,
/// • the URL-scheme handoff between the widget and the app.
///
/// Stable across launches when the same engine + palette + seed combine —
/// the engine is deterministic on `seed`.
public struct MandazaSnapshot: Codable, Hashable, Identifiable, Sendable {
    public var id: String { seed }
    public let seed: String
    public let paletteId: String
    public let config: EngineConfig
    /// When this snapshot was created or scheduled to display.
    public let date: Date

    public init(seed: String = UUID().uuidString,
                paletteId: String,
                config: EngineConfig,
                date: Date = .now) {
        self.seed = seed
        self.paletteId = paletteId
        self.config = config
        self.date = date
    }
}
