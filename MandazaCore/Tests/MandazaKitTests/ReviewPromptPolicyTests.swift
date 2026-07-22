import XCTest
#if SWIFT_PACKAGE
@testable import MandazaKit
#endif

@MainActor
final class ReviewPromptPolicyTests: XCTestCase {
    private let day: TimeInterval = 24 * 60 * 60

    func testExportPolicyRequiresRepeatUseAndSuccessfulExports() {
        let now = Date(timeIntervalSince1970: 2_000_000)
        let ready = ReviewPromptState(
            firstUseDate: now.addingTimeInterval(-8 * day),
            sessionCount: 3,
            meaningfulEventCount: 2
        )

        XCTAssertTrue(ReviewPromptPolicy.shouldRequest(
            state: ready,
            requirements: .imageExport,
            now: now,
            appVersion: "1.3"
        ))

        var tooSoon = ready
        tooSoon.firstUseDate = now.addingTimeInterval(-6 * day)
        XCTAssertFalse(ReviewPromptPolicy.shouldRequest(
            state: tooSoon,
            requirements: .imageExport,
            now: now,
            appVersion: "1.3"
        ))
    }

    func testPolicyAllowsOnlyOneAttemptPerVersion() {
        let now = Date(timeIntervalSince1970: 2_000_000)
        let state = ReviewPromptState(
            firstUseDate: now.addingTimeInterval(-400 * day),
            sessionCount: 20,
            meaningfulEventCount: 20,
            lastRequestDate: now.addingTimeInterval(-200 * day),
            lastRequestedVersion: "1.3"
        )

        XCTAssertFalse(ReviewPromptPolicy.shouldRequest(
            state: state,
            requirements: .imageExport,
            now: now,
            appVersion: "1.3"
        ))
        XCTAssertTrue(ReviewPromptPolicy.shouldRequest(
            state: state,
            requirements: .imageExport,
            now: now,
            appVersion: "1.4"
        ))
    }

    func testPolicyHonorsCooldownAcrossVersions() {
        let now = Date(timeIntervalSince1970: 2_000_000)
        let state = ReviewPromptState(
            firstUseDate: now.addingTimeInterval(-400 * day),
            sessionCount: 20,
            meaningfulEventCount: 20,
            lastRequestDate: now.addingTimeInterval(-30 * day),
            lastRequestedVersion: "1.2"
        )

        XCTAssertFalse(ReviewPromptPolicy.shouldRequest(
            state: state,
            requirements: .imageExport,
            now: now,
            appVersion: "1.3"
        ))
    }

    func testTrackerDoesNotDoubleCountOneSessionWindow() {
        let suiteName = "Mandaza.ReviewPromptPolicyTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let tracker = ReviewPromptTracker(defaults: defaults)
        let now = Date(timeIntervalSince1970: 2_000_000)

        tracker.recordSession(now: now)
        tracker.recordSession(now: now.addingTimeInterval(60))
        tracker.recordSession(now: now.addingTimeInterval(7 * 60 * 60))

        XCTAssertEqual(tracker.state.sessionCount, 2)
        XCTAssertEqual(tracker.state.firstUseDate, now)
    }
}
