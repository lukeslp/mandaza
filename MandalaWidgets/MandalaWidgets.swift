import SwiftUI
import WidgetKit

// MARK: - StandBy (and large Home Screen)

struct StandByMandalaWidget: Widget {
    let kind: String = "StandByMandala"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind,
                               intent: MandalaWidgetIntent.self,
                               provider: MandalaProvider()) { entry in
            StandByMandalaView(entry: entry)
                .containerBackground(.black, for: .widget)
        }
        .supportedFamilies([.systemLarge, .systemExtraLarge])
        .configurationDisplayName("StandBy Mandala")
        .description("Ambient mandala for your nightstand StandBy or Home Screen.")
    }
}

private struct StandByMandalaView: View {
    let entry: MandalaEntry

    var body: some View {
        ZStack {
            GeometryReader { geo in
                MandalaImageView(snapshot: entry.snapshot,
                                 size: geo.size,
                                 scale: 2)
            }
            if entry.intent.showTime {
                VStack(spacing: 4) {
                    Text(entry.date, style: .time)
                        .font(.system(size: 64, weight: .ultraLight, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.75), radius: 12)
                    Text(entry.date,
                         format: .dateTime.weekday(.wide).month(.wide).day())
                        .font(.callout.weight(.light))
                        .foregroundStyle(.white.opacity(0.75))
                        .shadow(color: .black.opacity(0.75), radius: 6)
                }
                .padding()
            }
        }
        .widgetURL(URL(string: "mandala://seed/\(entry.snapshot.seed)"))
    }
}

// MARK: - Lock Screen

struct LockMandalaWidget: Widget {
    let kind: String = "LockMandala"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind,
                               intent: MandalaWidgetIntent.self,
                               provider: MandalaProvider()) { entry in
            LockMandalaView(entry: entry)
                .containerBackground(.black, for: .widget)
        }
        .supportedFamilies([.accessoryRectangular, .accessoryCircular, .accessoryInline])
        .configurationDisplayName("Mandala — Lock")
        .description("A glimpse of a generative mandala on your Lock Screen.")
    }
}

private struct LockMandalaView: View {
    @Environment(\.widgetFamily) private var family
    let entry: MandalaEntry

    var body: some View {
        switch family {
        case .accessoryInline:
            Text("✦ Mandala")
        case .accessoryCircular:
            GeometryReader { geo in
                MandalaImageView(snapshot: entry.snapshot,
                                 size: geo.size,
                                 scale: 2)
                    .clipShape(Circle())
            }
            .widgetURL(URL(string: "mandala://seed/\(entry.snapshot.seed)"))
        default:
            // Rectangular
            HStack(spacing: 8) {
                GeometryReader { geo in
                    MandalaImageView(snapshot: entry.snapshot,
                                     size: geo.size,
                                     scale: 2)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .frame(width: 56)
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.date, style: .time)
                        .font(.headline)
                        .monospacedDigit()
                    Text("Mandala")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .widgetURL(URL(string: "mandala://seed/\(entry.snapshot.seed)"))
        }
    }
}

// MARK: - Home Screen (small / medium)

struct HomeMandalaWidget: Widget {
    let kind: String = "HomeMandala"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind,
                               intent: MandalaWidgetIntent.self,
                               provider: MandalaProvider()) { entry in
            HomeMandalaView(entry: entry)
                .containerBackground(.black, for: .widget)
        }
        .supportedFamilies([.systemSmall, .systemMedium])
        .configurationDisplayName("Mandala")
        .description("A generative mandala that rotates on its own schedule.")
    }
}

private struct HomeMandalaView: View {
    let entry: MandalaEntry

    var body: some View {
        GeometryReader { geo in
            MandalaImageView(snapshot: entry.snapshot,
                             size: geo.size,
                             scale: 2)
        }
        .widgetURL(URL(string: "mandala://seed/\(entry.snapshot.seed)"))
    }
}
