//
//  TimerViewModel.swift
//  GustavTimer
//
//  Created by Dalibor Janeček on 19.04.2023.
//

import Foundation
import Combine
import SwiftUI
import SwiftData
import TelemetryDeck

/// ViewModel pro správu časovače – iOS vrstva nad sdíleným TimerEngine
class TimerViewModel: ObservableObject {

    // MARK: - Sdílený engine
    let engine = TimerEngine(
        maxTimers: AppConfig.maxTimerCount,
        maxCountdownValue: AppConfig.maxTimerValue,
        countdownDuration: AppConfig.countdownDuration
    )

    // MARK: - Nastavení aktivního timeru

    /// Kompletní nastavení běžícího timeru. Jediný zdroj pravdy – čte se
    /// z `TimerData` (order == 0) a přes `apply(_:resetState:)` se rozvede
    /// do enginu i do zpětné vazby.
    ///
    /// Do verze 2.3 tady byla řada `@AppStorage` vlastností, které se rozcházely
    /// s tím, co bylo uložené v databázi. Viz `TimerSettings`.
    @Published private(set) var settings: TimerSettings = .default

    // MARK: - Události pro view
    //
    // ViewModel neví, jak view vypadá – animace ikon ani prezentaci sheetů
    // neřídí. Jen dává vědět, že se něco stalo.

    /// Počítadlo přechodů intervalu. View podle něj přehraje animaci ikon
    /// zvuku a vibrací.
    ///
    ///     .onChange(of: viewModel.intervalPulse) { _, _ in playFeedbackIcons() }
    @Published private(set) var intervalPulse = 0

    /// Počítadlo dokončených kol – pro animaci ikony smyčky.
    @Published private(set) var roundPulse = 0

    /// View má ukázat sheet (nastavení po načtení odkazu, „co je nového“).
    var onPresentSheet: ((AppSheet) -> Void)?

    /// Timer z odkazu (zvenku i z banneru), který čeká na potvrzení uživatele.
    /// `TimerView` na něj reaguje dotazem (`SharedLinkPrompt`) a podle
    /// odpovědi zavolá `confirmPendingSharedLink()` nebo
    /// `declinePendingSharedLink()`. Do té doby se timer nemění.
    @Published private(set) var pendingSharedLink: PendingSharedLink?

    // MARK: - Statistiky a stav aplikace (UserDefaults)
    @AppStorage(AppPreferences.Key.stopCounter) var stopCounter: Int = 0
    @AppStorage(AppPreferences.Key.completedTimerCount) var completedTimerCount: Int = 0
    @AppStorage(AppPreferences.Key.whatsNewVersion) var whatsNewVersion: Int = 0

    // MARK: - Review prompt
    var onReviewRequested: (() -> Void)?

    // MARK: - Soukromé vlastnosti
    private var modelContext: ModelContext?
    private let feedbackPlayer = TimerFeedbackPlayer()
    /// Analytika tréninku (`timer.started` / `completed` / `stopped`).
    private let workoutTracker = WorkoutSessionTracker()
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Forwarded properties z engine

    /// Pole intervalů – proxy na engine.intervals
    var timers: [IntervalData] {
        get { engine.intervals }
        set { engine.intervals = newValue }
    }

    var isTimerRunning: Bool { engine.isRunning }
    var isCountingDown: Bool { engine.isCountingDown }
    var countdownValue: Int { engine.countdownValue }
    var hasCountdown: Bool { engine.hasCountdown }
    var activeTimerIndex: Int { engine.activeTimerIndex }
    var finishedRounds: Int { engine.finishedRounds }
    var count: Int { engine.count }
    var progress: Double { engine.progress }

    // MARK: - Inicializace
    init() {
        setupEngineCallbacks()
        bindEngineChanges()
    }

    // MARK: - Propojení s engine

    /// Přeposílá objectWillChange z engine do tohoto ViewModelu
    private func bindEngineChanges() {
        engine.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    /// Nastaví platform-specific callbacky na engine
    private func setupEngineCallbacks() {
        engine.onFeedback = { [weak self] feedback in
            guard let self else { return }
            // Vibrace a zvuky podle nastavení – viz TimerFeedbackPlayer.
            self.feedbackPlayer.play(feedback, settings: self.settings, isRunning: self.engine.isRunning)

            switch feedback {
            case .intervalTransition:
                self.intervalPulse += 1
            case .roundComplete:
                self.roundPulse += 1
            case .timerEnd:
                self.workoutCompleted()
            case .countdownTick, .countdownEnd, .secondTick:
                break
            }
        }

        engine.onStart = {
            UIApplication.shared.isIdleTimerDisabled = true
        }

        engine.onStop = { [weak self] in
            guard let self else { return }
            UIApplication.shared.isIdleTimerDisabled = false
            self.stopCounter += 1
        }
    }

    // MARK: - Aplikace nastavení

    /// Jediné místo, kde se nastavení timeru dostává do enginu.
    /// Zvuk, vibrace a tikání si zpětná vazba čte přímo ze `settings`.
    private func apply(_ new: TimerSettings, resetState: Bool) {
        settings = new
        engine.rounds = new.rounds
        engine.hasCountdown = new.hasCountdown
        engine.loadIntervals(new.intervals, resetState: resetState)
    }

    // MARK: - Nastavení kontextu
    func setModelContext(_ context: ModelContext) {
        modelContext = context
        loadTimers(resetCurrentState: true)
    }

    func reloadTimers(resetCurrentState: Bool = false) {
        if resetCurrentState { trackAbandoned(.settings) }
        loadTimers(resetCurrentState: resetCurrentState)
    }

    // MARK: - Úpravy v otevřeném nastavení
    //
    // Otevření nastavení rozběhnutý timer nezastaví. Zastaví ho až úprava
    // průběhu (intervaly, kola, název) – po zavření se pak timer načte znovu
    // od začátku. Zvuk, haptika, tikání a odpočet se převezmou za běhu.

    /// Hlavní timer se změnil, zatímco je otevřené nastavení.
    func settingsEdited(_ new: TimerSettings) {
        if new.matchesProgram(of: settings) {
            applyFeedback(new)
        } else if engine.isRunning {
            stopTimer()
        }
    }

    /// Nastavení se zavřelo. Reset jen tehdy, když se změnil průběh.
    func settingsClosed(_ new: TimerSettings) {
        if new.matchesProgram(of: settings) {
            applyFeedback(new)
        } else {
            reloadTimers(resetCurrentState: true)
        }
    }

    /// Převezme zpětnou vazbu bez zásahu do odpočtu. Zvuk, haptiku a tikání
    /// si zpětná vazba čte ze `settings`; odpočet engine řeší až při startu.
    private func applyFeedback(_ new: TimerSettings) {
        settings = new
        engine.hasCountdown = new.hasCountdown
    }

    // MARK: - Ovládání timeru (deleguje na engine)

    /// - Parameter input: čím uživatel timer ovládl, jde do `timer.started`.
    func startStopTimer(input: TimerInput = .button) {
        if !engine.isRunning, !timers.isEmpty {
            trackStart(input: input)
        }

        engine.startStop()
    }

    func stopTimer() {
        engine.stop()
    }

    func resetTimer() {
        trackAbandoned(.reset)
        engine.reset()
    }

    func skipLap() {
        engine.skipCurrentInterval()
    }

    // MARK: - Formátování času

    func formattedCurrentTime(timeDisplayFormat: TimeDisplayFormat) -> String {
        engine.formattedCurrentTime(format: timeDisplayFormat)
    }

    // MARK: - Dokončení tréninku

    /// Trénink doběhl do konce: započítat ho a jednou za čas požádat o hodnocení.
    private func workoutCompleted() {
        completedTimerCount += 1
        if workoutTracker.completed(completedCount: completedTimerCount) {
            TelemetryDeck.coreFeatureUsed(featureName: "timer_completed")
        }

        guard completedTimerCount % AppConfig.reviewPromptInterval == 0 else { return }
        Analytics.send(.reviewRequested, parameters: [
            "completed_count": String(completedTimerCount)
        ])
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.onReviewRequested?()
        }
    }

    // MARK: - Co je nového
    func showWhatsNew() {
        // Čerstvá instalace: uživatel dostane onboarding, „co je nového“ by bylo
        // duplicitní. Verzi si jen zapíšeme, ať se ukáže až u příštího updatu.
        guard whatsNewVersion > 0 else {
            whatsNewVersion = AppConfig.version
            return
        }
        if whatsNewVersion < AppConfig.version {
            onPresentSheet?(.whatsNew)
            whatsNewVersion = AppConfig.version
        }
    }

    // MARK: - Deep Links

    /// Vstupní bod pro obě formy odkazu – historické `gustavtimerapp://timer?...`
    /// i Universal Link `https://gustavtraining.com/t?...`. Rozpoznání i normalizaci
    /// dělá `SharedTimerLink.route`, takže existuje jediná parsovací cesta.
    ///
    /// - Parameter fromApp: odkaz otevřený z obsahu aplikace (banner) přes
    ///   `AppLinkRouter`, ne zvenku. Nepočítá se jako akvizice.
    func handleDeepLink(url: URL, fromApp: Bool = false) {
        switch SharedTimerLink.route(url: url) {
        case .whatsNew:
            onPresentSheet?(.whatsNew)
        case .screen(let screen):
            // Nastavení otevře TimerView, obrazovku v něm SettingsView.
            AppNavigator.shared.open(screen)
        case .sharedTimer(let items):
            guard let link = SharedTimerLink.parse(items: items, limits: AppConfig.sharedLinkLimits) else {
                // Odkaz bez platného intervalu – timer se nemění, není se na co ptát.
                Analytics.linkOpened(url: url, items: items, link: nil, fromApp: fromApp, outcome: .invalid)
                return
            }
            // Odkaz přepíše timer (i rozběhnutý trénink) – nejdřív se zeptat,
            // ať přišel zvenku, nebo z banneru. Nový odkaz nahradí ten, který
            // na odpověď ještě čeká.
            pendingSharedLink = PendingSharedLink(url: url, items: items, link: link, fromApp: fromApp)
        case nil:
            print("Neznámý deep link: \(url)")
        }
    }

    /// Uživatel potvrdil načtení timeru z odkazu.
    func confirmPendingSharedLink() {
        guard let pending = pendingSharedLink else { return }
        pendingSharedLink = nil
        load(pending.link)
        Analytics.linkOpened(pending, outcome: .accepted)
    }

    /// Uživatel načtení timeru z odkazu odmítl – nic se nemění.
    func declinePendingSharedLink() {
        guard let pending = pendingSharedLink else { return }
        pendingSharedLink = nil
        Analytics.linkOpened(pending, outcome: .declined)
    }

    /// Načte timer ze sdíleného odkazu, který uživatel potvrdil, a otevře
    /// nastavení, ať ho hned vidí.
    ///
    /// Odkaz bez jediného platného intervalu sem nedojde – `parse` vrátí
    /// `nil` a stávající timer, počet kol ani uložená data se nezmění.
    private func load(_ link: SharedTimerLink) {
        // Odkaz přepíše rozběhnutý trénink – započítat ho dřív, než zmizí.
        trackAbandoned(.link)

        // Odkaz přebije jen to, co skutečně nese. Odkaz z verze 2.2/2.3
        // neobsahuje zvuk ani vibrace, takže si uživatel nechá svoje.
        let merged = link.applied(to: settings)

        apply(merged, resetState: true)
        // Timer z odkazu v oblíbených není – aktivní timer se od oblíbeného odpojí.
        persist(merged, detachingSource: true)
        workoutTracker.linkLoaded(merged)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.onPresentSheet?(.settings)
        }
    }
}

// MARK: - Běh na pozadí
extension TimerViewModel {

    /// Reakce na přesun aplikace mezi popředím a pozadím.
    ///
    ///     TimerView()
    ///         .onChange(of: scenePhase) { _, phase in
    ///             viewModel.handleScenePhase(phase)
    ///         }
    ///
    /// Na pozadí se tik smyčky zhrubí (přesnost to neovlivní, ta se počítá
    /// z hodin). Po návratu engine dopočítá čas strávený mimo, takže timer
    /// naváže přesně tam, kde reálně je.
    func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .background:
            enterBackground()
        case .active:
            enterForeground()
        default:
            break
        }
    }

    private func enterBackground() {
        guard engine.isRunning else { return }
        // Na pozadí aplikaci systém během chvíle uspí. Než k tomu dojde, stačí
        // hrubší tik – na přesnost to vliv nemá, ta se počítá z hodin.
        engine.setTickInterval(.milliseconds(50))
    }

    private func enterForeground() {
        engine.setTickInterval(.milliseconds(10))
        // Kdyby aplikaci systém přece jen uspal (přerušené audio, úsporný režim),
        // tohle je místo, kde se odpočet srovná s realitou.
        engine.syncToWallClock()
    }
}

// MARK: - Správa dat
extension TimerViewModel {

    private func loadTimers(resetCurrentState: Bool = true) {
        guard let context = modelContext else {
            apply(.default, resetState: true)
            return
        }

        apply(TimerData.mainTimer(in: context).settings, resetState: resetCurrentState)
    }

    /// Zapíše kompletní nastavení do hlavního timeru (order == 0).
    ///
    /// - Parameter detachingSource: nový timer odjinud (odkaz) – zapomene,
    ///   ze kterého oblíbeného aktivní timer vznikl. Úprava intervalů ho
    ///   nechává, ta se ukáže jako neuložená úprava oblíbeného.
    private func persist(_ newSettings: TimerSettings, detachingSource: Bool = false) {
        guard let context = modelContext else { return }

        let main = TimerData.mainTimer(in: context)
        main.settings = newSettings
        if detachingSource {
            main.sourceID = nil
        }
        do {
            try context.save()
        } catch {
            print("Chyba při ukládání časovačů: \(error)")
            TelemetryDeck.errorOccurred(id: "timer.persist_failed", category: .thrownException)
        }
    }
}

// MARK: - Analytika tréninku
//
// Signály skládá a posílá `WorkoutSessionTracker`. Tady se mu jen předává,
// co ví engine a databáze.
private extension TimerViewModel {

    func trackStart(input: TimerInput) {
        // finishedRounds je číslo běžícího kola, před prvním startem 0.
        workoutTracker.started(
            settings,
            input: input,
            isResume: engine.finishedRounds > 0,
            favourites: favouriteSettings()
        )
    }

    /// Volat před resetem enginu, jinak se ztratí, kde uživatel skončil.
    func trackAbandoned(_ reason: WorkoutSessionTracker.StopReason) {
        workoutTracker.abandoned(reason: reason, position: workoutPosition)
    }

    var workoutPosition: WorkoutSessionTracker.Position {
        let remaining = engine.remainingTime.components
        return WorkoutSessionTracker.Position(
            round: engine.finishedRounds,
            activeIndex: engine.activeTimerIndex,
            remainingSeconds: Double(remaining.seconds) + Double(remaining.attoseconds) / 1e18
        )
    }

    func favouriteSettings() -> [TimerSettings] {
        guard let modelContext else { return [] }
        return FavouriteTimers.favourites(in: modelContext).map(\.settings)
    }
}
