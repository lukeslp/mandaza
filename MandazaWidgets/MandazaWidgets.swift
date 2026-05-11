import SwiftUI
import WidgetKit

// MARK: - StandBy (and large Home Screen)

struct StandByMandazaWidget: Widget {
    let kind: String = "StandByMandaza"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind,
                               intent: MandazaWidgetIntent.self,
                               provider: MandazaProvider()) { entry in
            StandByMandazaView(entry: entry)
                .containerBackground(.black, for: .widget)
        }
        .supportedFamilies([.systemLarge, .systemExtraLarge])
        .configurationDisplayName("StandBy Mandaza")
        .description("Ambient mandaza for your nightstand StandBy or Home Screen.")
    }
}

private struct StandByMandazaView: View {
    let entry: MandazaEntry

    var body: some View {
        ZStack {
            GeometryReader { geo in
                MandazaImageView(snapshot: entry.snapshot,
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
        .widgetURL(URL(string: "mandaza://seed/\(entry.snapshot.seed)"))
    }
}

// MARK: - Lock Screen

struct LockMandazaWidget: Widget {
    let kind: String = "LockMandaza"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind,
                               intent: MandazaWidgetIntent.self,
                               provider: MandazaProvider()) { entry in
            LockMandazaView(entry: entry)
                .containerBackground(.black, for: .widget)
        }
        .supportedFamilies([.accessoryRectangular, .accessoryCircular, .accessoryInline])
        .configurationDisplayName("Mandaza — Lock")
        .description("A glimpse of a generative mandaza on your Lock Screen.")
    }
}

private struct LockMandazaView: View {
    @Environment(\.widgetFamily) private var family
    let entry: MandazaEntry

    var body: some View {
        switch family {
        case .accessoryInline:
            Text("✦ Mandaza")
        case .accessoryCircular:
            GeometryReader { geo in
                MandazaImageView(snapshot: entry.snapshot,
                                 size: geo.size,
                                 scale: 2)
                    .clipShape(Circle())
            }
            .widgetURL(URL(string: "mandaza://seed/\(entry.snapshot.seed)"))
        default:
            // Rectangular
            HStack(spacing: 8) {
                GeometryReader { geo in
                    MandazaImageView(snapshot: entry.snapshot,
                                     size: geo.size,
                                     scale: 2)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .frame(width: 56)
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.date, style: .time)
                        .font(.headline)
                        .monospacedDigit()
                    Text("Mandaza")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .widgetURL(URL(string: "mandaza://seed/\(entry.snapshot.seed)"))
        }
    }
}

// MARK: - Home Screen (small / medium)

struct HomeMandazaWidget: Widget {
    let kind: String = "HomeMandaza"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind,
                               intent: MandazaWidgetIntent.self,
                               provider: MandazaProvider()) { entry in
            HomeMandazaView(entry: entry)
                .containerBackground(.black, for: .widget)
        }
        .supportedFamilies([.systemSmall, .systemMedium])
        .configurationDisplayName("Mandaza")
        .description("A generative mandaza that rotates on its own schedule.")
    }
}

private struct HomeMandazaView: View {
    let entry: MandazaEntry

    var body: some View {
        GeometryReader { geo in
            MandazaImageView(snapshot: entry.snapshot,
                             size: geo.size,
                             scale: 2)
        }
        .widgetURL(URL(string: "mandaza://seed/\(entry.snapshot.seed)"))
    }
}
