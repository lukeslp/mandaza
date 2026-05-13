import WidgetKit
import Foundation

struct MandazaEntry: TimelineEntry {
    let date: Date
    let snapshot: MandazaSnapshot
    let intent: MandazaWidgetIntent
}

@MainActor
struct MandazaProvider: AppIntentTimelineProvider {

    func placeholder(in context: Context) -> MandazaEntry {
        MandazaEntry(date: .now,
                     snapshot: Self.snapshot(at: .now, intent: MandazaWidgetIntent()),
                     intent: MandazaWidgetIntent())
    }

    func snapshot(for configuration: MandazaWidgetIntent,
                  in context: Context) async -> MandazaEntry {
        MandazaEntry(date: .now,
                     snapshot: Self.snapshot(at: .now, intent: configuration),
                     intent: configuration)
    }

    func timeline(for configuration: MandazaWidgetIntent,
                  in context: Context) async -> Timeline<MandazaEntry> {
        let now = Date.now
        let minutes = configuration.autoRotate ? configuration.interval.minutes : 60
        let count = configuration.autoRotate ? 24 : 6
        let entries: [MandazaEntry] = (0..<count).map { i in
            let date = now.addingTimeInterval(TimeInterval(i * minutes * 60))
            return MandazaEntry(date: date,
                                snapshot: Self.snapshot(at: date, intent: configuration),
                                intent: configuration)
        }
        return Timeline(entries: entries, policy: .after(entries.last?.date ?? now))
    }

    /// Deterministic per rotation bucket — so the widget shows the same image
    /// every refresh inside a bucket, and changes on the boundary.
    private static func snapshot(at date: Date,
                                 intent: MandazaWidgetIntent) -> MandazaSnapshot {
        let bucketMinutes = intent.interval.minutes
        let bucket = Int(date.timeIntervalSince1970) / max(60, bucketMinutes * 60)
        let palette = intent.palette.resolved()
        let config = MandazaSettings.shared.engineConfig()
        let seed = "widget-\(bucket)-\(bucketMinutes)-\(palette)"

        // If the user has favorites and the bucket lines up, prefer a favorite.
        let favorites = MandazaSettings.shared.favorites
        if !favorites.isEmpty, bucket % 3 == 0 {
            let fav = favorites[abs(bucket) % favorites.count]
            return MandazaSnapshot(seed: fav.seed,
                                   paletteId: fav.paletteId,
                                   config: fav.config,
                                   date: date)
        }

        return MandazaSnapshot(seed: seed,
                               paletteId: palette,
                               config: config,
                               date: date)
    }
}
