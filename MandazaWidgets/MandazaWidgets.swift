/*
 File Purpose: Defines Mandaza's StandBy, Lock Screen, and Home Screen widgets.
 Primary Components: Three Widget configurations and their snapshot views.
 Inputs / Outputs: Renders MandazaEntry snapshots and opens the app with an
 encoded snapshot route that restores the displayed artwork.
 */

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
                    .accessibilityHidden(true)
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
        .widgetURL(MandazaDeepLink.url(for: entry.snapshot))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Opens this pattern in Mandaza.")
    }

    private var accessibilityLabel: String {
        var parts = ["Mandaza", "\(Palette.by(id: entry.snapshot.paletteId).name) pattern"]
        if entry.intent.showTime {
            parts.append(entry.date.formatted(date: .omitted, time: .shortened))
            parts.append(entry.date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
        }
        return parts.joined(separator: ", ")
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
        Group {
            switch family {
            case .accessoryInline:
                Text("✦ Mandaza")
            case .accessoryCircular:
                GeometryReader { geo in
                    MandazaImageView(snapshot: entry.snapshot,
                                     size: geo.size,
                                     scale: 2)
                        .clipShape(Circle())
                        .accessibilityHidden(true)
                }
            default:
                // Rectangular
                HStack(spacing: 8) {
                    GeometryReader { geo in
                        MandazaImageView(snapshot: entry.snapshot,
                                         size: geo.size,
                                         scale: 2)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .accessibilityHidden(true)
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
            }
        }
        .widgetURL(MandazaDeepLink.url(for: entry.snapshot))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Opens this pattern in Mandaza.")
    }

    private var accessibilityLabel: String {
        var parts = ["Mandaza", "\(Palette.by(id: entry.snapshot.paletteId).name) pattern"]
        if family == .accessoryRectangular {
            parts.append(entry.date.formatted(date: .omitted, time: .shortened))
        }
        return parts.joined(separator: ", ")
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
                .accessibilityHidden(true)
        }
        .widgetURL(MandazaDeepLink.url(for: entry.snapshot))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Mandaza, \(Palette.by(id: entry.snapshot.paletteId).name) pattern")
        .accessibilityHint("Opens this pattern in Mandaza.")
    }
}
