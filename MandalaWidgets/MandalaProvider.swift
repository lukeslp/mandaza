import WidgetKit
import Foundation

struct MandalaEntry: TimelineEntry {
    let date: Date
    let snapshot: MandalaSnapshot
    let intent: MandalaWidgetIntent
}

struct MandalaProvider: AppIntentTimelineProvider {

    func placeholder(in context: Context) -> MandalaEntry {
        MandalaEntry(date: .now,
                     snapshot: Self.snapshot(at: .now, intent: MandalaWidgetIntent()),
                     intent: MandalaWidgetIntent())
    }

    func snapshot(for configuration: MandalaWidgetIntent,
                  in context: Context) async -> MandalaEntry {
        MandalaEntry(date: .now,
                     snapshot: Self.snapshot(at: .now, intent: configuration),
                     intent: configuration)
    }

    func timeline(for configuration: MandalaWidgetIntent,
                  in context: Context) async -> Timeline<MandalaEntry> {
        let now = Date.now
        let minutes = configuration.autoRotate ? configuration.interval.minutes : 60
        let count = configuration.autoRotate ? 24 : 6
        let entries: [MandalaEntry] = (0..<count).map { i in
            let date = now.addingTimeInterval(TimeInterval(i * minutes * 60))
            return MandalaEntry(date: date,
                                snapshot: Self.snapshot(at: date, intent: configuration),
                                intent: configuration)
        }
        return Timeline(entries: entries, policy: .after(entries.last?.date ?? now))
    }

    /// Deterministic per rotation bucket — so the widget shows the same image
    /// every refresh inside a bucket, and changes on the boundary.
    private static func snapshot(at date: Date,
                                 intent: MandalaWidgetIntent) -> MandalaSnapshot {
        let bucketMinutes = intent.interval.minutes
        let bucket = Int(date.timeIntervalSince1970) / max(60, bucketMinutes * 60)
        let palette = MainActor.assumeIsolated { intent.palette.resolved() }
        let config = MainActor.assumeIsolated { MandalaSettings.shared.engineConfig() }
        let seed = "widget-\(bucket)-\(bucketMinutes)-\(palette)"

        // If the user has favorites and the bucket lines up, prefer a favorite.
        let favorites = MainActor.assumeIsolated { MandalaSettings.shared.favorites }
        if !favorites.isEmpty, bucket % 3 == 0 {
            let fav = favorites[abs(bucket) % favorites.count]
            return MandalaSnapshot(seed: fav.seed,
                                   paletteId: fav.paletteId,
                                   config: fav.config,
                                   date: date)
        }

        return MandalaSnapshot(seed: seed,
                               paletteId: palette,
                               config: config,
                               date: date)
    }
}
