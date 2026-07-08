#if os(iOS) || os(watchOS)
#if canImport(AVFoundation)
import AVFoundation
import Foundation
import Observation

/// Live microphone → modulation bridge for audio-reactive rendering.
///
/// Configures the shared `AVAudioSession` as `.playAndRecord` + `.mixWithOthers`
/// so the mic tap visualizes ambient sound WITHOUT silencing other apps' audio
/// (`.record` would). On iOS the built-in mic is preferred so AirPods stay on
/// A2DP. The render-thread tap downmixes to mono, analyzes 1024-sample windows,
/// and hops smoothed band energies to the MainActor `source`.
///
/// Survives interruptions (phone calls, Siri) and route / engine configuration
/// changes by reinstalling the tap with a FRESH input format — reusing a stale
/// format after a sample-rate change crashes.
@MainActor
@Observable
public final class AudioReactor {

    public enum State: Equatable {
        case idle
        case denied
        case running
        case interrupted
        case failed(String)
    }

    public private(set) var state: State = .idle

    /// Downstream views observe this for smoothed, main-actor modulation values.
    public let source = MandazaModulationSource()

    @ObservationIgnored private let engine = AVAudioEngine()
    @ObservationIgnored private let processor = TapProcessor()
    @ObservationIgnored private var observers: [NSObjectProtocol] = []

    @ObservationIgnored private var smoothed = MandazaModulation.zero
    @ObservationIgnored private var lastWritten = MandazaModulation.zero
    @ObservationIgnored private var colorPhaseMs: Double = 0
    @ObservationIgnored private var lastApplyUptime: TimeInterval? = nil

    public init() {
        installObservers()
    }

    deinit {
        for token in observers {
            NotificationCenter.default.removeObserver(token)
        }
    }

    // MARK: - Lifecycle

    public func start() async {
        guard state != .running else { return }

        let granted = await AVAudioApplication.requestRecordPermission()
        guard granted else {
            state = .denied
            return
        }

        do {
            let session = AVAudioSession.sharedInstance()
            #if os(iOS)
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.mixWithOthers, .allowBluetoothA2DP, .defaultToSpeaker])
            #else
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.mixWithOthers])
            #endif
            try session.setActive(true)
            #if os(iOS)
            if let builtIn = session.availableInputs?.first(where: { $0.portType == .builtInMic }) { try? session.setPreferredInput(builtIn) }
            #endif

            try startEngine()
            state = .running
            source.isActive = true
        } catch {
            teardown()
            state = .failed(error.localizedDescription)
        }
    }

    public func stop() {
        teardown()
        state = .idle
    }

    private func teardown() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        source.isActive = false
        source.modulation = .zero
        smoothed = .zero
        lastWritten = .zero
        colorPhaseMs = 0
        lastApplyUptime = nil
    }

    // MARK: - Engine

    private func startEngine() throws {
        installTap()
        engine.prepare()
        try engine.start()
    }

    /// Installs (or reinstalls) the render tap using a FRESH input format.
    /// The analyzer is rebuilt so its FFT bins match the current sample rate.
    private func installTap() {
        let input = engine.inputNode
        input.removeTap(onBus: 0)
        let format = input.inputFormat(forBus: 0)
        processor.prepare(sampleRate: format.sampleRate)
        processor.onBands = { [weak self] bands, onset in
            Task { @MainActor in
                self?.apply(bands, onset: onset)
            }
        }
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [processor] buffer, _ in
            processor.process(buffer)
        }
    }

    // MARK: - Modulation

    private func apply(_ bands: SpectrumBands, onset: Bool) {
        guard state == .running else { return }

        let now = ProcessInfo.processInfo.systemUptime
        let dt = lastApplyUptime.map { max(0, now - $0) } ?? 0
        lastApplyUptime = now

        smoothed.level  = ema(smoothed.level,  toward: Double(bands.rms))
        smoothed.bass   = ema(smoothed.bass,   toward: Double(bands.bass))
        smoothed.mid    = ema(smoothed.mid,    toward: Double(bands.mid))
        smoothed.treble = ema(smoothed.treble, toward: Double(bands.treble))
        smoothed.beatPulse = max(smoothed.beatPulse * exp(-dt / 0.18), onset ? 1.0 : 0.0)

        // Always accumulates internally; rides along on the next gated write.
        colorPhaseMs += dt * 1000 * (2.5 * smoothed.mid)
        smoothed.colorPhaseMs = colorPhaseMs

        let moved = abs(smoothed.level - lastWritten.level) > 0.01
            || abs(smoothed.bass - lastWritten.bass) > 0.01
            || abs(smoothed.mid - lastWritten.mid) > 0.01
            || abs(smoothed.treble - lastWritten.treble) > 0.01
            || abs(smoothed.beatPulse - lastWritten.beatPulse) > 0.01
        if moved {
            source.modulation = smoothed
            lastWritten = smoothed
        }
    }

    /// Asymmetric EMA: fast attack so hits register, slow release so the
    /// artwork breathes down instead of flickering.
    private func ema(_ current: Double, toward target: Double) -> Double {
        let coefficient = target > current ? 0.35 : 0.08
        return current + (target - current) * coefficient
    }

    // MARK: - Interruptions & route changes

    private func installObservers() {
        let nc = NotificationCenter.default
        observers.append(nc.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: nil) { [weak self] note in
            let type = (note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt)
                .flatMap(AVAudioSession.InterruptionType.init(rawValue:))
            let options = AVAudioSession.InterruptionOptions(
                rawValue: note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0)
            Task { @MainActor in
                self?.handleInterruption(type: type, options: options)
            }
        })
        observers.append(nc.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: nil) { [weak self] _ in
            Task { @MainActor in
                self?.handleConfigurationChange(routeChanged: true)
            }
        })
        observers.append(nc.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine, queue: nil) { [weak self] _ in
            Task { @MainActor in
                self?.handleConfigurationChange(routeChanged: false)
            }
        })
    }

    private func handleInterruption(type: AVAudioSession.InterruptionType?, options: AVAudioSession.InterruptionOptions) {
        switch type {
        case .began:
            guard state == .running else { return }
            engine.stop()
            state = .interrupted
        case .ended:
            guard state == .interrupted, options.contains(.shouldResume) else { return }
            do {
                try AVAudioSession.sharedInstance().setActive(true)
                try startEngine()
                state = .running
            } catch {
                teardown()
                state = .failed(error.localizedDescription)
            }
        default:
            break
        }
    }

    /// Reinstalls the tap with a fresh `inputFormat(forBus: 0)` — the previous
    /// format is stale after a route / configuration change and would crash.
    private func handleConfigurationChange(routeChanged: Bool) {
        #if os(iOS)
        if routeChanged, state == .running || state == .interrupted {
            let session = AVAudioSession.sharedInstance()
            if let builtIn = session.availableInputs?.first(where: { $0.portType == .builtInMic }) { try? session.setPreferredInput(builtIn) }
        }
        #endif
        guard state == .running else { return }
        engine.stop()
        do {
            try startEngine()
        } catch {
            teardown()
            state = .failed(error.localizedDescription)
        }
    }
}

/// Audio-render-thread stage: downmixes incoming PCM buffers to mono, slices
/// them into exact 1024-sample windows (accumulating remainders across
/// callbacks), analyzes each window, and reports bands + onset via `onBands`.
/// `@unchecked Sendable`: `prepare`/`onBands` are set while the tap is not
/// installed; `process` runs only on the tap thread.
private final class TapProcessor: @unchecked Sendable {
    static let windowSize = 1024

    private var analyzer: SpectrumAnalyzer?
    private var pending: [Float] = []
    var onBands: ((SpectrumBands, Bool) -> Void)?

    func prepare(sampleRate: Double) {
        analyzer = SpectrumAnalyzer(sampleRate: sampleRate, fftSize: Self.windowSize)
        pending.removeAll(keepingCapacity: true)
    }

    func process(_ buffer: AVAudioPCMBuffer) {
        guard let analyzer, let channels = buffer.floatChannelData else { return }
        let frames = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        guard frames > 0, channelCount > 0 else { return }

        if channelCount == 1 {
            pending.append(contentsOf: UnsafeBufferPointer(start: channels[0], count: frames))
        } else {
            let scale = 1 / Float(channelCount)
            pending.reserveCapacity(pending.count + frames)
            for i in 0..<frames {
                var sum: Float = 0
                for c in 0..<channelCount { sum += channels[c][i] }
                pending.append(sum * scale)
            }
        }

        while pending.count >= Self.windowSize {
            let window = Array(pending.prefix(Self.windowSize))
            pending.removeFirst(Self.windowSize)
            let bands = analyzer.analyze(window)
            let onset = analyzer.isOnset(flux: bands.flux)
            onBands?(bands, onset)
        }
    }
}
#endif
#endif
