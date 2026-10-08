//
//  TimerLiveActivityController.swift
//  GustavTimer
//
//  Obsluha Live Activity – jediné místo, které mluví s ActivityKitem.
//
//  Pravidla, kterými se řídí:
//
//  1. Aktivita se zakládá při startu timeru a končí s ním (reset, doběhnutí,
//     odchod do nastavení). Mezitím se jen aktualizuje.
//  2. Posílá se výhradně při změně plánu – start, pauza, přechod intervalu,
//     skip, návrat z pozadí. Nikdy ne každou sekundu: odpočty si systém vykreslí
//     sám z absolutních dat a časté updaty ActivityKit stejně přiškrtí.
//  3. Stejný plán se neposílá dvakrát. Data se počítají z `Date()`, takže dva
//     stavy téhož plánu se liší o milisekundy – porovnává se s tolerancí.
//  4. `staleDate` = konec aktuálního intervalu. Když aplikace spí a přechod
//     nepošle, dlaždice se od té chvíle přepne na čas celého tréninku.
//

import Foundation
import ActivityKit

@MainActor
final class TimerLiveActivityController {

    static let shared = TimerLiveActivityController()

    private var activity: Activity<TimerActivityAttributes>?
    private var lastState: TimerActivityAttributes.ContentState?
    private var isRequesting = false

    private init() {}

    /// Zda uživatel Live Activities pro aplikaci vůbec povolil
    /// (Nastavení → GustavTimer → Živé aktivity).
    var isAvailable: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    /// Založí aktivitu, nebo – pokud už běží – pošle nový stav.
    /// Volá se z `TimerViewModel` při startu, pauze a konci.
    func sync(state: TimerActivityAttributes.ContentState) {
        // Uživatel může mít Live Activities vypnuté v nastavení aplikace.
        guard isAvailable else { return }

        // Posun dat o pár milisekund (tik smyčky, návrat do popředí)
        // za update nestojí.
        if let lastState, lastState.isSamePlan(as: state) { return }
        lastState = state

        if let activity {
            let content = ActivityContent(state: state, staleDate: Self.staleDate(for: state))
            Task { await activity.update(content) }
        } else {
            start(state: state)
        }
    }

    /// Ukončí aktivitu a sundá ji z obrazovky.
    func finish() {
        guard let activity else {
            reset()
            return
        }
        self.activity = nil
        reset()

        Task { await activity.end(nil, dismissalPolicy: .immediate) }
    }

    private func reset() {
        lastState = nil
    }

    /// Uklidí aktivity, které mohly přežít pád nebo vynucené ukončení aplikace.
    /// Volá se při startu aplikace.
    func endOrphanedActivities() {
        for activity in Activity<TimerActivityAttributes>.activities where activity.id != self.activity?.id {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }

    // MARK: - Privátní

    private func start(state: TimerActivityAttributes.ContentState) {
        guard !isRequesting else { return }
        isRequesting = true
        defer { isRequesting = false }

        do {
            activity = try Activity.request(
                attributes: TimerActivityAttributes(),
                content: ActivityContent(state: state, staleDate: Self.staleDate(for: state)),
                pushType: nil
            )
        } catch {
            print("Live Activity se nepodařilo spustit: \(error.localizedDescription)")
            reset()
        }
    }

    /// Aktuální interval přestane platit svým koncem. Pozastavený timer
    /// nezestárne nikdy – odpočet stojí a aplikace ho rozběhne sama.
    private static func staleDate(for state: TimerActivityAttributes.ContentState) -> Date? {
        state.phase == .running ? state.intervalEnd : nil
    }
}

private extension TimerActivityAttributes.ContentState {

    /// Odchylka, pod kterou se dva stavy považují za stejný plán.
    /// Zobrazuje se na celé sekundy, takže čtvrt sekundy nikdo nepozná.
    static let tolerance: TimeInterval = 0.25

    func isSamePlan(as other: Self) -> Bool {
        phase == other.phase
            && (pausedAt == nil) == (other.pausedAt == nil)
            && intervalName == other.intervalName
            && abs(intervalEnd.timeIntervalSince(other.intervalEnd)) < Self.tolerance
            && abs(start.timeIntervalSince(other.start)) < Self.tolerance
            && Self.close(end, other.end)
    }

    private static func close(_ lhs: Date?, _ rhs: Date?) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil): true
        case let (lhs?, rhs?): abs(lhs.timeIntervalSince(rhs)) < tolerance
        default: false
        }
    }
}
