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
//  Když aplikaci zavře uživatel nebo systém, není komu konec ohlásit.
//  Rozběhnutý trénink se proto ukládá (`InterruptedWorkoutStore`) a jeho
//  `timer.stopped` s `reason=app_closed` se pošle při dalším spuštění.
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
        /// Zavření aplikace. Posílá se až při dalším spuštění.
        case appClosed = "app_closed"
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
        let id = UUID()
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
    private let store: InterruptedWorkoutStore

    /// - Parameters:
    ///   - send: odeslání signálu; testy sem dávají záznamník.
    ///   - now: aktuální čas; testy s ním posouvají hodiny.
    ///   - store: kam se ukládá rozběhnutý trénink; testy mají vlastní.
    init(
        send: @escaping Send = { Analytics.send($0, parameters: $1, floatValue: $2) },
        now: @escaping () -> Date = { .now },
        store: InterruptedWorkoutStore = InterruptedWorkoutStore()
    ) {
        self.send = send
        self.now = now
        self.store = store
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
            // Na úplném začátku, než přijde první skutečná poloha.
            savePosition(Position(
                round: 1,
                activeIndex: 0,
                remainingSeconds: Double(settings.intervals.first?.value ?? 0)
            ))
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
        close(session)

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
        close(session)

        let stopped = stoppedSignal(session, reason: reason, position: position())
        send(.timerStopped, stopped.parameters, stopped.elapsed)
    }

    /// Uloží, kde trénink je, pro případ, že se aplikace zavře. Volat při
    /// pauze a při odchodu z popředí – tam ještě je kdy zapisovat.
    ///
    /// Čas na pozadí se sem nedostane: aplikace tam spí a nic neukládá.
    func savePosition(_ position: @autoclosure () -> Position) {
        guard let session else { return }
        let stopped = stoppedSignal(session, reason: .appClosed, position: position())
        store.save(InterruptedWorkout(id: session.id, parameters: stopped.parameters, elapsed: stopped.elapsed))
    }

    /// Pošle `timer.stopped` za trénink, který minule ukončilo zavření
    /// aplikace. Volat jednou při startu, po `TelemetryDeck.initialize`
    /// a dřív, než může začít nový trénink.
    static func reportInterrupted(
        store: InterruptedWorkoutStore = InterruptedWorkoutStore(),
        send: Send = { Analytics.send($0, parameters: $1, floatValue: $2) }
    ) {
        guard let workout = store.load() else { return }
        store.clear()
        send(.timerStopped, workout.parameters, workout.elapsed)
    }

    private func close(_ session: Session) {
        self.session = nil
        store.clear(id: session.id)
    }

    private func stoppedSignal(
        _ session: Session,
        reason: StopReason,
        position: Position
    ) -> (parameters: [String: String], elapsed: Double) {
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
        return (parameters, progress.elapsed)
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

// MARK: - Přerušený trénink

/// Hotový signál `timer.stopped` za trénink, který ještě běží. Drží rovnou
/// parametry, ne nastavení – neuloží se tak nic, co by se neposílalo.
struct InterruptedWorkout: Codable, Equatable {
    /// Ke kterému tréninku patří.
    let id: UUID
    let parameters: [String: String]
    /// Odcvičené sekundy.
    let elapsed: Double
}

/// Úložiště rozběhnutého tréninku v `UserDefaults`.
struct InterruptedWorkoutStore {

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func save(_ workout: InterruptedWorkout) {
        guard let data = try? JSONEncoder().encode(workout) else { return }
        defaults.set(data, forKey: AppPreferences.Key.interruptedWorkout)
    }

    func load() -> InterruptedWorkout? {
        defaults.data(forKey: AppPreferences.Key.interruptedWorkout)
            .flatMap { try? JSONDecoder().decode(InterruptedWorkout.self, from: $0) }
    }

    func clear() {
        defaults.removeObject(forKey: AppPreferences.Key.interruptedWorkout)
    }

    /// Smaže jen daný trénink. Na iPadu může mít druhé okno uložený svůj.
    func clear(id: UUID) {
        guard load()?.id == id else { return }
        clear()
    }
}
