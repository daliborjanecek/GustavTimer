//
//  WorkoutSessionTrackerTests.swift
//  GustavTimerTests
//
//  Created by Dalibor Janeček on 11.11.2026.
//
//  Testuje analytiku tréninku (`WorkoutSessionTracker`) a parametry signálu
//  `timer.link_opened`. Nic se neposílá – tracker dostane záznamník místo
//  skutečného odeslání a hodiny, které se dají posunout.
//

import Testing
import Foundation
@testable import GustavTimer

/// Zaznamená signály, které by tracker jinak odeslal.
private final class SignalRecorder {
    struct Signal {
        let signal: AnalyticsSignal
        let parameters: [String: String]
        let floatValue: Double?
    }

    private(set) var signals: [Signal] = []
    var time = Date(timeIntervalSince1970: 1_000_000)

    func makeTracker() -> WorkoutSessionTracker {
        WorkoutSessionTracker(
            send: { [unowned self] in signals.append(Signal(signal: $0, parameters: $1, floatValue: $2)) },
            now: { [unowned self] in time }
        )
    }
}

/// Vlastní timer, který se neshoduje s žádným presetem: 37 s práce, 13 s pauza.
private func customTimer(rounds: Int = 4) -> TimerSettings {
    TimerSettings(
        name: "Vlastní",
        intervals: [IntervalData(value: 37, name: "Work"), IntervalData(value: 13, name: "Rest")],
        rounds: rounds,
        sound: .beep,
        isVibrating: true,
        ticking: .off,
        hasCountdown: true
    )
}

private func position(round: Int, activeIndex: Int = 0, remaining: Double = 0) -> WorkoutSessionTracker.Position {
    WorkoutSessionTracker.Position(round: round, activeIndex: activeIndex, remainingSeconds: remaining)
}

struct WorkoutSessionTrackerTests {

    @Test func firstStartOpensSession() {
        let recorder = SignalRecorder()
        let tracker = recorder.makeTracker()

        tracker.started(customTimer(), input: .tap, isResume: false, favourites: [])

        #expect(recorder.signals.count == 1)
        let started = recorder.signals[0]
        #expect(started.signal == .timerStarted)
        #expect(started.parameters["input"] == "tap")
        #expect(started.parameters["is_resume"] == "false")
        #expect(started.parameters["timer_origin"] == "custom")
        #expect(started.parameters["interval_pattern"] == "37/13")
    }

    @Test func originComesFromPresetFavouriteOrLink() {
        let preset = PredefinedTimer.tabata
        let recorder = SignalRecorder()
        let tracker = recorder.makeTracker()

        tracker.started(preset.settings, input: .button, isResume: false, favourites: [])
        tracker.started(customTimer(), input: .button, isResume: false, favourites: [customTimer()])
        tracker.linkLoaded(customTimer(rounds: 9))
        tracker.started(customTimer(rounds: 9), input: .button, isResume: false, favourites: [])

        #expect(recorder.signals.map { $0.parameters["timer_origin"] } == ["preset", "favourite", "link"])
        #expect(recorder.signals[0].parameters["preset"] == preset.rawValue)
        #expect(recorder.signals[1].parameters["preset"] == nil)
    }

    /// Pauza trénink nekončí: pokračování nese `is_resume` a doba se dál
    /// počítá od prvního startu.
    @Test func resumeKeepsSession() {
        let recorder = SignalRecorder()
        let tracker = recorder.makeTracker()

        tracker.started(customTimer(), input: .button, isResume: false, favourites: [])
        recorder.time += 60
        tracker.started(customTimer(), input: .button, isResume: true, favourites: [])
        recorder.time += 40
        tracker.completed(completedCount: 3)

        #expect(recorder.signals.map(\.signal) == [.timerStarted, .timerStarted, .timerCompleted])
        #expect(recorder.signals[1].parameters["is_resume"] == "true")
        #expect(recorder.signals[2].floatValue == 100)
    }

    @Test func completedReportsCountAndOrigin() {
        let recorder = SignalRecorder()
        let tracker = recorder.makeTracker()
        tracker.started(customTimer(), input: .button, isResume: false, favourites: [])

        #expect(tracker.completed(completedCount: 7))

        let completed = recorder.signals[1]
        #expect(completed.signal == .timerCompleted)
        #expect(completed.parameters["completed_count"] == "7")
        #expect(completed.parameters["timer_origin"] == "custom")
    }

    @Test func completedWithoutSessionSendsNothing() {
        let recorder = SignalRecorder()
        let tracker = recorder.makeTracker()

        #expect(!tracker.completed(completedCount: 1))
        #expect(recorder.signals.isEmpty)
    }

    /// Ve 2. kole ve druhém intervalu, zbývá 3 s: 50 + 37 + 10 = 97 s z 200.
    @Test func abandonedReportsProgressAndOrigin() {
        let recorder = SignalRecorder()
        let tracker = recorder.makeTracker()
        tracker.started(customTimer(), input: .button, isResume: false, favourites: [])

        tracker.abandoned(reason: .reset, position: position(round: 2, activeIndex: 1, remaining: 3))

        let stopped = recorder.signals[1]
        #expect(stopped.signal == .timerStopped)
        #expect(stopped.parameters["reason"] == "reset")
        #expect(stopped.parameters["round"] == "2")
        #expect(stopped.parameters["progress_pct"] == "40")
        #expect(stopped.floatValue == 97)
        // Původ se dřív u `timer.stopped` ztrácel.
        #expect(stopped.parameters["timer_origin"] == "custom")
    }

    @Test func abandonedEndsSession() {
        let recorder = SignalRecorder()
        let tracker = recorder.makeTracker()
        tracker.started(customTimer(), input: .button, isResume: false, favourites: [])

        tracker.abandoned(reason: .settings, position: position(round: 1))
        tracker.abandoned(reason: .link, position: position(round: 1))
        tracker.completed(completedCount: 1)

        #expect(recorder.signals.map(\.signal) == [.timerStarted, .timerStopped])
    }

    @Test func loopHasNoProgressPercent() {
        let recorder = SignalRecorder()
        let tracker = recorder.makeTracker()
        tracker.started(customTimer(rounds: -1), input: .button, isResume: false, favourites: [])

        tracker.abandoned(reason: .reset, position: position(round: 3))

        #expect(recorder.signals[1].parameters["progress_pct"] == "loop")
    }
}

struct SharedLinkAnalyticsTests {

    private func parameters(
        _ string: String,
        fromApp: Bool = false,
        outcome: SharedLinkOutcome
    ) throws -> [String: String] {
        let url = try #require(URL(string: string))
        guard case .sharedTimer(let items)? = SharedTimerLink.route(url: url) else {
            Issue.record("Odkaz není odkaz na timer")
            return [:]
        }
        let link = SharedTimerLink.parse(items: items, limits: AppConfig.sharedLinkLimits)
        return Analytics.linkOpenedParameters(url: url, items: items, link: link, fromApp: fromApp, outcome: outcome)
    }

    @Test func acceptedUniversalLink() throws {
        let result = try parameters(
            "https://gustavtraining.com/t?Work=30&Rest=15&_sound=beep&utm_source=whatsapp&utm_campaign=spring",
            outcome: .accepted
        )
        #expect(result["link_type"] == "universal")
        #expect(result["source"] == "whatsapp")
        #expect(result["campaign"] == "spring")
        #expect(result["loaded"] == "true")
        #expect(result["prompt"] == "accepted")
        #expect(result["interval_pattern"] == "30/15")
        #expect(result["has_settings"] == "true")
    }

    /// Odkaz ze starší verze: vlastní schéma, bez kanálu a bez nastavení.
    @Test func declinedLegacyLink() throws {
        let result = try parameters("gustavtimerapp://timer?Work=30", outcome: .declined)
        #expect(result["link_type"] == "scheme")
        #expect(result["source"] == "unknown")
        #expect(result["campaign"] == nil)
        #expect(result["loaded"] == "false")
        #expect(result["prompt"] == "declined")
        #expect(result["has_settings"] == "false")
    }

    @Test func linkFromBannerIsInApp() throws {
        let result = try parameters("https://gustavtraining.com/t?Work=30", fromApp: true, outcome: .accepted)
        #expect(result["link_type"] == "in_app")
    }

    /// Odkaz bez platného intervalu: dotaz se neukázal, timer se nezměnil.
    @Test func invalidLinkIsNotLoaded() throws {
        let result = try parameters("https://gustavtraining.com/t?utm_source=mail", outcome: .invalid)
        #expect(result["loaded"] == "false")
        #expect(result["prompt"] == "none")
        #expect(result["source"] == "mail")
        #expect(result["interval_pattern"] == nil)
    }
}
