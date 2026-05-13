import WidgetKit
import Foundation

struct MandazaEntry: TimelineEntry {
    let date: Date
    let snapshot: MandazaSnapshot
    let intent: MandazaWidgetIntent
}

struct MandazaProvider: AppIntentTimelineProvider {

    func placeholder(in context: Context) -> MandazaEntry {
        let intent = MandazaWidgetIntent()
        return MandazaEntry(date: .now,
                            snapshot: Self.placeholderSnapshot(at: .now, intent: intent),
                            intent: intent)
    }

    func snapshot(for configuration: MandazaWidgetIntent,
                  in context: Context) async -> MandazaEntry {
        return MandazaEntry(date: .now,
                            snapshot: await Self.snapshotUsingSharedSettings(at: .now, intent: configuration),
                            intent: configuration)
    }

    func timeline(for configuration: MandazaWidgetIntent,
                  in context: Context) async -> Timeline<MandazaEntry> {
        let now = Date.now
        let minutes = configuration.autoRotate ? configuration.interval.minutes : 60
        let count = configuration.autoRotate ? 24 : 6
        var entries: [MandazaEntry] = []
        entries.reserveCapacity(count)
        for i in 0..<count {
            let date = now.addingTimeInterval(TimeInterval(i * minutes * 60))
            let snap = await Self.snapshotUsingSharedSettings(at: date, intent: configuration)
            entries.append(MandazaEntry(date: date, snapshot: snap, intent: configuration))
        }
        return Timeline(entries: entries, policy: .after(entries.last?.date ?? now))
    }

    /// Placeholder avoids crossing into App Group / actor-isolated settings reads.
    private static func placeholderSnapshot(at date: Date,
                                            intent: MandazaWidgetIntent) -> MandazaSnapshot {
        let bucketMinutes = intent.interval.minutes
        let bucket = Int(date.timeIntervalSince1970) / max(60, bucketMinutes * 60)
        let palette = intent.palette == .followsApp ? "aurora" : intent.palette.rawValue
        let seed = "widget-\(bucket)-\(bucketMinutes)-\(palette)"
        return MandazaSnapshot(seed: seed,
                               paletteId: palette,
                               config: EngineConfig(),
                               date: date)
    }

    /// Deterministic per rotation bucket — so the widget shows the same image
    /// every refresh inside a bucket, and changes on the boundary.
    private static func snapshotUsingSharedSettings(at date: Date,
                                                    intent: MandazaWidgetIntent) async -> MandazaSnapshot {
        let bucketMinutes = intent.interval.minutes
        let bucket = Int(date.timeIntervalSince1970) / max(60, bucketMinutes * 60)
        return await MainActor.run {
            let palette = intent.palette.resolved()
            let seed = "widget-\(bucket)-\(bucketMinutes)-\(palette)"
            let config = MandazaSettings.shared.engineConfig()
            let favorites = MandazaSettings.shared.favorites
            // If the user has favorites and the bucket lines up, prefer a favorite.
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
}
