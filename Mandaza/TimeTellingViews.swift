import SwiftUI
import UIKit

@MainActor
final class TimeHapticPlayer: ObservableObject {
    @Published private(set) var isPlaying = false
    private var playback: Task<Void, Never>?

    func play(date: Date = .now,
              exactMinutes: Bool,
              intensity: Double,
              tempo: Double) {
        stop()
        let pulses = TimePulsePattern.make(channels: TimeChannels(date: date),
                                           exactMinutes: exactMinutes,
                                           tempo: tempo)
        let clampedIntensity = min(max(intensity, 0.2), 1)
        isPlaying = true
        playback = Task { @MainActor [weak self] in
            defer { self?.isPlaying = false }
            for pulse in pulses {
                guard !Task.isCancelled else { return }
                let style: UIImpactFeedbackGenerator.FeedbackStyle
                let multiplier: Double
                switch pulse.strength {
                case .strong: style = .heavy; multiplier = 1
                case .medium: style = .medium; multiplier = 0.78
                case .light: style = .light; multiplier = 0.55
                }
                let generator = UIImpactFeedbackGenerator(style: style)
                generator.prepare()
                generator.impactOccurred(intensity: clampedIntensity * multiplier)
                if pulse.delayAfter > 0 {
                    try? await Task.sleep(for: .seconds(pulse.delayAfter))
                }
            }
        }
    }

    func stop() {
        playback?.cancel()
        playback = nil
        isPlaying = false
    }

    deinit { playback?.cancel() }
}

struct TimeTellingOverlay: View {
    let mode: TimeTellingMode
    let accent: Color
    let clockwise: Bool
    let ringWeight: Double
    let hapticsEnabled: Bool
    let exactMinutes: Bool
    let hapticIntensity: Double
    let hapticTempo: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var haptics = TimeHapticPlayer()

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let channels = TimeChannels(date: context.date)
            VStack(spacing: 24) {
                if mode == .concentricRings {
                    ConcentricTimeRings(channels: channels,
                                        accent: accent,
                                        clockwise: clockwise,
                                        weight: ringWeight,
                                        animate: !reduceMotion)
                } else {
                    RhythmTimeGlyph(channels: channels, accent: accent)
                }
                if hapticsEnabled {
                    Button {
                        if haptics.isPlaying {
                            haptics.stop()
                        } else {
                            haptics.play(date: context.date,
                                         exactMinutes: exactMinutes,
                                         intensity: hapticIntensity,
                                         tempo: hapticTempo)
                        }
                    } label: {
                        Label(haptics.isPlaying ? "Stop" : "Feel current time",
                              systemImage: haptics.isPlaying ? "stop.fill" : "waveform")
                            .font(.headline)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 12)
                            .background(.black.opacity(0.62), in: Capsule())
                    }
                    .foregroundStyle(.white)
                    .accessibilityHint("Plays strong hour pulses, medium five-minute pulses, and optional light minute taps.")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(28)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Time encoded as \(channels.spokenDescription)")
        }
        .onDisappear { haptics.stop() }
    }
}

private struct ConcentricTimeRings: View {
    let channels: TimeChannels
    let accent: Color
    let clockwise: Bool
    let weight: Double
    let animate: Bool

    var body: some View {
        ZStack {
            ring(progress: channels.hourProgress, diameter: 230, opacity: 1, dash: [])
            ring(progress: channels.groupProgress, diameter: 174, opacity: 0.82, dash: [9, 5])
            ring(progress: channels.minuteProgress, diameter: 118, opacity: 0.64, dash: [2, 5])
            VStack(spacing: 2) {
                Text("\(channels.hour)").font(.system(size: 40, weight: .bold, design: .rounded))
                Text(String(format: "%02d", channels.minute))
                    .font(.system(size: 18, weight: .medium, design: .monospaced))
            }
            .foregroundStyle(.white)
        }
        .frame(width: 250, height: 250)
        .animation(animate ? .easeInOut(duration: 0.8) : nil, value: channels.minute)
    }

    private func ring(progress: Double,
                      diameter: CGFloat,
                      opacity: Double,
                      dash: [CGFloat]) -> some View {
        let width = CGFloat(4 + min(max(weight, 0), 1) * 10)
        return ZStack {
            Circle().stroke(.white.opacity(0.12), lineWidth: width)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(accent.opacity(opacity),
                        style: StrokeStyle(lineWidth: width, lineCap: .round, dash: dash))
                .rotationEffect(.degrees(clockwise ? -90 : 90))
                .scaleEffect(x: clockwise ? 1 : -1, y: 1)
        }
        .frame(width: diameter, height: diameter)
    }
}

private struct RhythmTimeGlyph: View {
    let channels: TimeChannels
    let accent: Color

    var body: some View {
        VStack(spacing: 16) {
            pulseRow(count: channels.hour, color: accent, size: 15)
            pulseRow(count: channels.fiveMinuteGroups, color: accent.opacity(0.78), size: 11)
            pulseRow(count: channels.remainingMinutes, color: accent.opacity(0.56), size: 7)
            Text("strong hours · medium groups · light minutes")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.68))
        }
        .padding(24)
        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 24))
    }

    private func pulseRow(count: Int, color: Color, size: CGFloat) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(size), spacing: 8), count: 4), spacing: 8) {
            ForEach(0..<count, id: \.self) { _ in
                Circle().fill(color).frame(width: size, height: size)
            }
        }
        .frame(minHeight: size)
    }
}

struct TimeModeSettingsControls: View {
    @Bindable var settings: MandazaSettings
    let accent: Color

    private var mode: Binding<TimeTellingMode> {
        Binding(get: { settings.timeTellingMode }, set: { settings.timeTellingMode = $0 })
    }

    var body: some View {
        Picker("Time language", selection: mode) {
            Text("Classic").tag(TimeTellingMode.classic)
            Text("Concentric rings").tag(TimeTellingMode.concentricRings)
            Text("Encoded rhythm").tag(TimeTellingMode.encodedRhythm)
        }
        .pickerStyle(.menu)

        if settings.timeTellingMode == .concentricRings {
            Toggle("Clockwise rings", isOn: $settings.timeRingsClockwise)
            settingsSlider("Ring weight", value: $settings.timeRingsWeight, range: 0 ... 1) {
                "\(Int($0 * 100))%"
            }
        }

        if settings.timeTellingMode != .classic {
            Toggle("Haptic time", isOn: $settings.timeHapticsEnabled)
            if settings.timeHapticsEnabled {
                Toggle("Exact minute taps", isOn: $settings.timeHapticsExactMinutes)
                settingsSlider("Haptic strength", value: $settings.timeHapticsIntensity, range: 0.2 ... 1) {
                    "\(Int($0 * 100))%"
                }
                settingsSlider("Rhythm speed", value: $settings.timeHapticsTempo, range: 0.12 ... 0.6) {
                    String(format: "%.2fs", $0)
                }
            }
        }
    }

    private func settingsSlider(_ title: String,
                                value: Binding<Double>,
                                range: ClosedRange<Double>,
                                format: @escaping (Double) -> String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                Text(format(value.wrappedValue)).monospacedDigit().foregroundStyle(.secondary)
            }
            Slider(value: value, in: range).tint(accent)
                .accessibilityLabel(title)
                .accessibilityValue(format(value.wrappedValue))
        }
    }
}
