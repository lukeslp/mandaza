#if canImport(WatchConnectivity)
import Foundation
import Observation
import WatchConnectivity

/// Bridges `WCSession` into the app's Observation world. The iOS app pushes
/// settings (debounced application context) and snapshots (message with a
/// user-info fallback); the watch app receives both and applies them via
/// `WatchSync`. Delegate callbacks arrive on a background queue, so every
/// touch of published state or `MandazaSettings` hops to the main actor.
@MainActor
@Observable
public final class WatchSyncController: NSObject {

    public static let shared = WatchSyncController()

    // MARK: - Published state

    public private(set) var activationState: WCSessionActivationState = .notActivated
    public private(set) var isReachable = false
    #if os(iOS)
    public private(set) var isPaired = false
    public private(set) var isWatchAppInstalled = false
    #endif

    // MARK: - Hooks (set by the watch app)

    public var onSnapshotReceived: (@MainActor (MandazaSnapshot) -> Void)?
    public var onSettingsReceived: (@MainActor () -> Void)?

    @ObservationIgnored
    private var pushTask: Task<Void, Never>?

    private override init() {
        super.init()
    }

    // MARK: - Activation

    public func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    // MARK: - Sending (phone side)

    #if os(iOS)
    /// Debounced push of the full settings context. Slider drags fire many
    /// times per second; only the value 0.5 s after the last change ships.
    public func pushSettings(_ settings: MandazaSettings) {
        pushTask?.cancel()
        pushTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            try? WCSession.default.updateApplicationContext(
                WatchSync.settingsContext(from: settings))
        }
    }

    /// Sends a snapshot immediately when the watch is reachable, otherwise
    /// (or on send failure) queues it via `transferUserInfo` for delivery
    /// when the watch app next runs.
    public func send(snapshot: MandazaSnapshot) {
        let message = WatchSync.snapshotMessage(snapshot)
        let session = WCSession.default
        if session.isReachable {
            session.sendMessage(message, replyHandler: nil) { _ in
                session.transferUserInfo(message)
            }
        } else {
            session.transferUserInfo(message)
        }
    }
    #endif
}

// MARK: - WCSessionDelegate

extension WatchSyncController: WCSessionDelegate {

    public nonisolated func session(_ session: WCSession,
                                    activationDidCompleteWith activationState: WCSessionActivationState,
                                    error: Error?) {
        let reachable = session.isReachable
        #if os(iOS)
        let paired = session.isPaired
        let installed = session.isWatchAppInstalled
        #endif
        #if os(watchOS)
        // Context delivered while the watch app was dead lands here rather
        // than in didReceiveApplicationContext.
        let pendingContext = session.receivedApplicationContext
        #endif
        Task { @MainActor in
            self.activationState = activationState
            self.isReachable = reachable
            #if os(iOS)
            self.isPaired = paired
            self.isWatchAppInstalled = installed
            #endif
            #if os(watchOS)
            if !pendingContext.isEmpty {
                WatchSync.applySettingsContext(pendingContext, to: MandazaSettings.shared)
                self.onSettingsReceived?()
            }
            #endif
        }
    }

    public nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        Task { @MainActor in
            self.isReachable = reachable
        }
    }

    #if os(iOS)
    public nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    public nonisolated func sessionDidDeactivate(_ session: WCSession) {
        // Re-activate so the session follows a switch to another paired watch.
        session.activate()
    }

    public nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        let paired = session.isPaired
        let installed = session.isWatchAppInstalled
        Task { @MainActor in
            self.isPaired = paired
            self.isWatchAppInstalled = installed
        }
    }
    #endif

    #if os(watchOS)
    public nonisolated func session(_ session: WCSession,
                                    didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in
            WatchSync.applySettingsContext(applicationContext, to: MandazaSettings.shared)
            self.onSettingsReceived?()
        }
    }

    public nonisolated func session(_ session: WCSession,
                                    didReceiveMessage message: [String: Any]) {
        Task { @MainActor in
            guard let snapshot = WatchSync.decodeSnapshot(from: message) else { return }
            self.onSnapshotReceived?(snapshot)
        }
    }

    public nonisolated func session(_ session: WCSession,
                                    didReceiveUserInfo userInfo: [String: Any] = [:]) {
        Task { @MainActor in
            guard let snapshot = WatchSync.decodeSnapshot(from: userInfo) else { return }
            self.onSnapshotReceived?(snapshot)
        }
    }
    #endif
}
#endif
