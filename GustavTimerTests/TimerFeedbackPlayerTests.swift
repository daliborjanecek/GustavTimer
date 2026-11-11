//
//  TimerFeedbackPlayerTests.swift
//  GustavTimerTests
//
//  Created by Dalibor Janeček on 11.11.2026.
//
//  Testuje, jaké vibrace a zvuky patří ke které události enginu.
//  Samotné přehrání (UIKit, AVAudioPlayer) se netestuje.
//

import Testing
@testable import GustavTimer

private func settings(
    sound: SoundModel? = .beep,
    isVibrating: Bool = true,
    ticking: TickingMode = .off
) -> TimerSettings {
    TimerSettings(
        name: "Tabata",
        intervals: [IntervalData(value: 20, name: "Work")],
        rounds: 8,
        sound: sound,
        isVibrating: isVibrating,
        ticking: ticking,
        hasCountdown: true
    )
}

private func effects(
    _ feedback: TimerFeedback,
    _ settings: TimerSettings,
    isRunning: Bool = true
) -> [TimerFeedbackPlayer.Effect] {
    TimerFeedbackPlayer.effects(for: feedback, settings: settings, isRunning: isRunning)
}

struct TimerFeedbackPlayerTests {

    @Test func intervalTransitionVibratesAndPlaysSound() {
        #expect(effects(.intervalTransition, settings()) == [.lightHaptic, .sound(.beep)])
    }

    @Test func roundCompleteUsesStrongerHaptic() {
        #expect(effects(.roundComplete, settings()) == [.successHaptic, .sound(.beep)])
    }

    @Test func hapticsOffKeepsSound() {
        #expect(effects(.intervalTransition, settings(isVibrating: false)) == [.sound(.beep)])
    }

    @Test func stoppedTimerDoesNotVibrateOnTransition() {
        #expect(effects(.intervalTransition, settings(), isRunning: false) == [.sound(.beep)])
    }

    /// Engine se na konci zastaví dřív, než událost dorazí.
    @Test func timerEndVibratesEvenWhenStopped() {
        #expect(effects(.timerEnd, settings(), isRunning: false) == [.endHaptic, .sound(.beep)])
    }

    @Test func countdownOnlyVibrates() {
        #expect(effects(.countdownTick, settings()) == [.lightHaptic])
        #expect(effects(.countdownEnd, settings()) == [.successHaptic])
        #expect(effects(.countdownTick, settings(isVibrating: false)).isEmpty)
    }

    @Test func mutedTransitionIsSilentWithoutTicking() {
        #expect(effects(.intervalTransition, settings(sound: nil, isVibrating: false)).isEmpty)
    }

    /// Při ztlumeném zvuku doplní přechod tik, který by jinak vynechal.
    @Test(arguments: [TickingMode.everySecond, .finalSeconds])
    func mutedTransitionTicksWhenTickingIsOn(_ ticking: TickingMode) {
        #expect(effects(.intervalTransition, settings(sound: nil, isVibrating: false, ticking: ticking)) == [.tick])
    }

    @Test func soundReplacesTickOnTransition() {
        #expect(effects(.intervalTransition, settings(isVibrating: false, ticking: .everySecond)) == [.sound(.beep)])
    }

    @Test func secondTickFollowsTickingMode() {
        #expect(effects(.secondTick(remainingSeconds: 10), settings(ticking: .off)).isEmpty)
        #expect(effects(.secondTick(remainingSeconds: 10), settings(ticking: .everySecond)) == [.tick])
        #expect(effects(.secondTick(remainingSeconds: 10), settings(ticking: .finalSeconds)).isEmpty)
        #expect(effects(.secondTick(remainingSeconds: 2), settings(ticking: .finalSeconds)) == [.tick])
    }
}
