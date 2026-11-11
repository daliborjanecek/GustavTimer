//
//  WorkoutSessionTracker.swift
//  GustavTimer
//
//  Created by Dalibor Janeček on 11.11.2026.
//
//  Analytika jednoho tréninku. Trychtýř:
//
//      timer.started (is_resume=false) → timer.completed
//                                      → timer.stopped   (vzdaný trénink)
//
//  Trénink trvá od prvního startu do dokončení nebo resetu. Pauza ho
//  neukončí, takže `timer.stopped` znamená opravdu vzdaný trénink.
//
//  Dřív tohle dělal `TimerViewModel` sám. Tady jde otestovat bez enginu
//  i bez sítě – odeslání signálu se dá při vytvoření nahradit
//  (`WorkoutSessionTrackerTests`).
//
//      tracker.started(settings, input: .button, isResume: false, favourites: favourites)
//      tracker.abandoned(reason: .reset, position: position)
//

import Foundation

final class WorkoutSessionTracker {

    typealias Send = (_ signal: AnalyticsSignal, _ parameters: [String: String], _ floatValue: Double?) -> Void

    /// Proč rozběhnutý trénink skončil dřív, než doběhl.
    enum StopReason: String {
        /// Tlačítko reset.
        case reset
        /// Zavření nastavení se změnou průběhu.
        case settings
        /// Přepsání timerem z odkazu.
        case link
    }

    /// Kde trénink právě je, jak to vede engine.
    struct Position {
        /// Číslo běžícího kola (`finishedRounds` – po prvním startu 1).
        let round: Int
        let activeIndex: Int
        /// Kolik sekund zbývá z aktivního intervalu.
        let remainingSeconds: Double
    }

    private struct Session {
        let startedAt: Date
        let settings: TimerSettings
        let origin: TimerOrigin
        let presetID: String?
    }

    private var session: Session?

    /// Nastavení z posledního načteného odkazu. Podle něj `timer.started`
    /// pozná, že trénink přišel z odkazu. Drží se jen v paměti.
    private var lastLinkSettings: TimerSettings?

    private let send: Send
    private let now: () -> Date

    /// - Parameters:
    ///   - send: odeslání signálu; testy sem dávají záznamník.
    ///   - now: aktuální čas; testy s ním posouvají hodiny.
    init(
        send: @escaping Send = { Analytics.send($0, parameters: $1, floatValue: $2) },
        now: @escaping () -> Date = { .now }
    ) {
        self.send = send
        self.now = now
    }

    /// Timer se načetl ze sdíleného odkazu.
    func linkLoaded(_ settings: TimerSettings) {
        lastLinkSettings = settings
    }

    /// `timer.started`. První start zahájí trénink a určí jeho původ,
    /// pokračování po pauze nese `is_resume=true`.
    ///
    /// - Parameter favourites: uložené oblíbené pro určení původu. Vyhodnotí
    ///   se jen při zahájení tréninku, ne při každém pokračování.
    func started(
        _ settings: TimerSettings,
        input: TimerInput,
        isResume: Bool,
        favourites: @autoclosure () -> [TimerSettings]
    ) {
        if !isResume || session == nil {
            let (origin, presetID) = Analytics.origin(
                of: settings,
                presets: PredefinedTimer.allCases.map { (id: $0.rawValue, settings: $0.settings) },
                favourites: favourites(),
                lastLink: lastLinkSettings
            )
            session = Session(startedAt: now(), settings: settings, origin: origin, presetID: presetID)
        }

        var parameters = Analytics.parameters(for: settings)
        parameters["input"] = input.rawValue
        parameters["is_resume"] = Analytics.boolValue(isResume)
        addOrigin(of: session, to: &parameters)
        send(.timerStarted, parameters, nil)
    }

    /// `timer.completed` – trénink doběhl do konce. `floatValue` je reálná
    /// doba od prvního startu včetně pauz, v sekundách.
    ///
    /// - Returns: `false`, když žádný trénink neběžel a nic se neposlalo.
    @discardableResult
    func completed(completedCount: Int) -> Bool {
        guard let session else { return false }
        self.session = nil

        var parameters = Analytics.parameters(for: session.settings)
        parameters["completed_count"] = String(completedCount)
        addOrigin(of: session, to: &parameters)
        send(.timerCompleted, parameters, now().timeIntervalSince(session.startedAt))
        return true
    }

    /// `timer.stopped` – rozběhnutý trénink skončil dřív, než doběhl.
    /// Volat před resetem enginu, jinak se ztratí, kde uživatel skončil.
    func abandoned(reason: StopReason, position: @autoclosure () -> Position) {
        guard let session else { return }
        self.session = nil

        let position = position()
        let progress = Analytics.workoutProgress(
            intervals: session.settings.intervals,
            rounds: session.settings.rounds,
            round: position.round,
            activeIndex: position.activeIndex,
            remainingSeconds: position.remainingSeconds
        )

        var parameters = Analytics.parameters(for: session.settings)
        parameters["reason"] = reason.rawValue
        parameters["round"] = String(position.round)
        parameters["elapsed"] = Analytics.durationBucket(seconds: progress.elapsed)
        parameters["progress_pct"] = progress.fraction.map(Analytics.percentBucket) ?? "loop"
        addOrigin(of: session, to: &parameters)
        send(.timerStopped, parameters, progress.elapsed)
    }

    /// Původ dostává trénink jako parametr. Dřív se četl z uloženého stavu,
    /// který byl u `timer.stopped` v tu chvíli už vymazaný, takže signál
    /// `timer_origin` nikdy nenesl.
    private func addOrigin(of session: Session?, to parameters: inout [String: String]) {
        guard let session else { return }
        parameters["timer_origin"] = session.origin.rawValue
        if let presetID = session.presetID {
            parameters["preset"] = presetID
        }
    }
}
