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
//  2. Posílá se výhradně při změně plánu – přechod intervalu, kolo, pauza.
//     Nikdy ne každou sekundu: odpočet si systém vykreslí sám z `intervalEnd`
//     a časté updaty ActivityKit stejně přiškrtí.
//  3. Stejný stav se neposílá dvakrát (ContentState je Hashable).
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

        // Stav je natolik hubený, že se mění jen při startu, pauze a konci –
        // porovnání celého obsahu tedy stačí.
        guard state != lastState else { return }
        lastState = state

        if let activity {
            let content = ActivityContent(state: state, staleDate: nil)
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
                content: ActivityContent(state: state, staleDate: nil),
                pushType: nil
            )
        } catch {
            print("Live Activity se nepodařilo spustit: \(error.localizedDescription)")
            reset()
        }
    }

    // `staleDate` se záměrně nenastavuje: dlaždice neukazuje nic, co by mohlo
    // zestárnout, takže není co označovat za neaktuální.
}
