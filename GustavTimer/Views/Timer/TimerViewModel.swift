//
//  TimerViewModel.swift
//  GustavTimer
//
//  Created by Dalibor Janeček on 19.04.2023.
//

import Foundation
import Combine
import SwiftUI
import AVKit
import AVFoundation
import SwiftData
import Lottie
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

    // MARK: - iOS-specific publikované vlastnosti
    @Published var showingSheet = false
    @Published var showingWhatsNew: Bool = false
    @Published var editMode = EditMode.inactive

    /// Počítadlo se zvýší při každém úspěšném načtení sdíleného odkazu.
    /// SettingsView na jeho změnu reaguje zobrazením alertu – oproti boolean
    /// příznaku funguje spolehlivě i když je Settings pořád otevřené z předchozího
    /// odkazu (aplikace jen na pozadí), kdy by zápis `true → true` do UserDefaults
    /// nevyvolal žádnou pozorovatelnou změnu.
    @AppStorage(AppPreferences.Key.deeplinkLoadToken) var deeplinkLoadToken: Int = 0

    /// Název timeru z `_title` posledního načteného odkazu. Prázdný řetězec
    /// znamená, že odkaz `_title` neobsahoval – SharedTimerLink.parse prázdný
    /// ani jen z mezer sestávající title nikdy nevrátí, takže je to bezpečná
    /// hodnota "chybí".
    @AppStorage(AppPreferences.Key.deeplinkLoadedTitle) var deeplinkLoadedTitle: String = ""

    // MARK: Lottie animation state
    @Published var appearanceIconAnimation = LottiePlaybackMode.paused(at: .frame(0))
    @Published var loopIconAnimation = LottiePlaybackMode.paused(at: .frame(0))

    // MARK: - Statistiky a stav aplikace (UserDefaults)
    @AppStorage(AppPreferences.Key.stopCounter) var stopCounter: Int = 0
    @AppStorage(AppPreferences.Key.completedTimerCount) var completedTimerCount: Int = 0
    @AppStorage(AppPreferences.Key.whatsNewVersion) var whatsNewVersion: Int = 0

    // MARK: - Review prompt
    var onReviewRequested: (() -> Void)?

    // MARK: - Soukromé vlastnosti
    private var modelContext: ModelContext?
    private var cancellables = Set<AnyCancellable>()

    /// Timer právě doběhl a Live Activity dobíhá se závěrečným snímkem.
    /// Reset, který po doběhnutí následuje, ji už nesmí přepsat ani sundat.
    private var isFinishingSession = false


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
    var isTimerFull: Bool { engine.isTimerFull }

    // MARK: - Inicializace
    init() {
        setupEngineCallbacks()
        bindEngineChanges()

        // Aktivita, která přežila vynucené ukončení aplikace, by na zamykací
        // obrazovce zůstala viset s dávno neplatným odpočtem.
        Task { @MainActor in
            TimerLiveActivityController.shared.endOrphanedActivities()
        }
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
            switch feedback {
            case .intervalTransition:
                self.vibrate()
                self.playSound()
                self.appearanceIconAnimation = .playing(
                    .fromProgress(0, toProgress: 1, loopMode: .playOnce)
                )
            case .roundComplete:
                self.vibrateRound()
                self.playSound()
                self.loopIconAnimation = .playing(
                    .fromProgress(0, toProgress: 1, loopMode: .playOnce)
                )
            case .timerEnd:
                self.vibrateEnd()
                self.playSound()
                self.isFinishingSession = true
                Task { @MainActor in TimerLiveActivityController.shared.finish() }
                self.completedTimerCount += 1
                if self.completedTimerCount % AppConfig.reviewPromptInterval == 0 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                        self?.onReviewRequested?()
                    }
                }
            case .countdownTick:
                self.vibrate()
            case .countdownEnd:
                self.vibrateRound()
            case .secondTick:
                self.playTickSound()
            }
        }

        engine.onStart = { [weak self] in
            guard let self else { return }
            UIApplication.shared.isIdleTimerDisabled = true
            self.isFinishingSession = false
        }

        engine.onStop = { [weak self] in
            guard let self else { return }
            UIApplication.shared.isIdleTimerDisabled = false
            self.stopCounter += 1
        }

        // Plán běhu se mění řádově jednou za interval – přesně tehdy má smysl
        // poslat nový stav do Live Activity.
        engine.onScheduleChange = { [weak self] in
            self?.refreshLiveActivity()
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
        loadTimers(resetCurrentState: resetCurrentState)
    }

    // MARK: - Ovládání timeru (deleguje na engine)

    func startStopTimer() {
        // Track timer start event before starting
        if !engine.isRunning, !timers.isEmpty {
            let intervalPattern = timers.map { String($0.value) }.joined(separator: "/")
            TelemetryDeck.signal(
                "timer.started",
                parameters: [
                    "interval_pattern": intervalPattern
                ]
            )
        }

        engine.startStop()
    }

    func stopTimer() {
        engine.stop()
    }

    func resetTimer() {
        engine.reset()
    }

    func skipLap() {
        engine.skipCurrentInterval()
    }

    // MARK: - Správa intervalů

    func addTimer() {
        engine.addInterval()
        persistIntervals()
    }

    func removeTimer(at offsets: IndexSet) {
        engine.removeInterval(at: offsets)
        persistIntervals()
    }

    func removeTimer(index: Int) {
        engine.removeInterval(at: index)
        persistIntervals()
    }

    // MARK: - Progress bar

    func getProgressBarWidth(geometry: GeometryProxy, timerIndex: Int) -> Double {
        guard timerIndex < timers.count else { return 0.0 }
        let totalWidth = geometry.size.width - (CGFloat(timers.count - 1) * 5)
        let ratio = engine.timeRatio(for: timerIndex)
        return totalWidth * ratio
    }

    // MARK: - Formátování času

    func formattedTime(from duration: Duration) -> String {
        engine.formattedTime(from: duration)
    }

    func formattedCurrentTime(timeDisplayFormat: TimeDisplayFormat) -> String {
        engine.formattedCurrentTime(format: timeDisplayFormat)
    }

    /// Zobrazení/skrytí nastavení
    func toggleSheet() {
        showingSheet.toggle()
        stopTimer()
        resetTimer()
    }

    // MARK: - Zpětná vazba (vibrace a zvuky) – iOS specific

    private func vibrate() {
        guard settings.isVibrating && engine.isRunning else { return }
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    private func vibrateRound() {
        guard settings.isVibrating && engine.isRunning else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    private func vibrateEnd() {
        guard settings.isVibrating else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }

    private func playSound() {
        if let sound = settings.sound {
            SoundManager.instance.playSound(soundModel: sound)
        } else {
            // Poslední sekunda intervalu nedostane .secondTick – engine místo ní
            // pošle .intervalTransition – takže tik při ztlumeném zvuku
            // doplňujeme tady. Bez toho by tikání na přechodu vynechalo.
            playTickSound()
        }
    }
    
    private func playTickSound() {
        guard settings.isTicking else { return }
        SoundManager.instance.playTick()
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
            showingWhatsNew = true
            whatsNewVersion = AppConfig.version
        }
    }

    // MARK: - Deep Links

    /// Vstupní bod pro obě formy odkazu – historické `gustavtimerapp://timer?...`
    /// i Universal Link `https://gustavtraining.com/t?...`. Rozpoznání i normalizaci
    /// dělá `SharedTimerLink.route`, takže existuje jediná parsovací cesta.
    func handleDeepLink(url: URL) {
        switch SharedTimerLink.route(url: url) {
        case .whatsNew:
            showingWhatsNew = true
        case .sharedTimer(let items):
            handleSharedTimer(items: items)
        case nil:
            print("Neznámý deep link: \(url)")
        }
    }

    /// Načte sdílený timer z query parametrů.
    ///
    /// Chování při vadném vstupu: pokud odkaz neobsahuje jediný platný interval
    /// (nesmyslné hodnoty, jen trackovací parametry, prázdný dotaz), `parse`
    /// vrátí `nil` a metoda nesáhne na nic – stávající timer, počet kol ani
    /// uložená data se nezmění a nastavení se neotevře. Jednotlivé neplatné
    /// parametry se ignorují, celý odkaz kvůli nim nepadá.
    func handleSharedTimer(items: [URLQueryItem]) {
        guard let link = SharedTimerLink.parse(items: items, limits: AppConfig.sharedLinkLimits) else { return }

        // Odkaz přebije jen to, co skutečně nese. Odkaz z verze 2.2/2.3
        // neobsahuje zvuk ani vibrace, takže si uživatel nechá svoje.
        let merged = link.applied(to: settings)

        apply(merged, resetState: true)
        persist(merged)

        deeplinkLoadedTitle = link.title ?? ""
        deeplinkLoadToken += 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.showingSheet = true
        }
    }
}

// MARK: - Live Activity a běh na pozadí
extension TimerViewModel {

    /// Reakce na přesun aplikace mezi popředím a pozadím.
    ///
    ///     TimerView()
    ///         .onChange(of: scenePhase) { _, phase in
    ///             viewModel.handleScenePhase(phase)
    ///         }
    ///
    /// Na pozadí odpočet vidí uživatel v Live Activity, tik smyčky se zhrubí
    /// (přesnost to neovlivní, ta se počítá z hodin). Po návratu engine dopočítá
    /// čas strávený mimo, takže timer naváže přesně tam, kde reálně je.
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
        refreshLiveActivity()
    }

    private func enterForeground() {
        engine.setTickInterval(.milliseconds(10))
        // Kdyby aplikaci systém přece jen uspal (přerušené audio, úsporný režim),
        // tohle je místo, kde se odpočet srovná s realitou.
        engine.syncToWallClock()
        refreshLiveActivity()
    }

    /// Pošle do Live Activity aktuální plán běhu. Volá se z `engine.onScheduleChange`,
    /// tedy při startu, pauze, přechodu intervalu, kole a resetu.
    func refreshLiveActivity() {
        guard !isFinishingSession else { return }

        // Timer stojí na začátku (po resetu nebo před prvním startem) – aktivita
        // by ukazovala odpočet, který nikam neběží.
        guard engine.isRunning || engine.finishedRounds > 0 else {
            Task { @MainActor in TimerLiveActivityController.shared.finish() }
            return
        }

        let state = makeLiveActivityState()
        Task { @MainActor in
            TimerLiveActivityController.shared.sync(state: state)
        }
    }

    /// Převede stav enginu na absolutní data pro Live Activity: aktuální interval
    /// a začátek a konec celého tréninku. Odpočty z nich kreslí systém sám.
    ///
    /// Interval platí jen do svého konce – další přechod pošle `onScheduleChange`,
    /// pokud aplikace ještě žije. Proto je konec intervalu zároveň `staleDate`
    /// a dlaždice má celý trénink jako zálohu, která platí vždy.
    private func makeLiveActivityState() -> TimerActivityAttributes.ContentState {
        let now = Date()
        let intervals = engine.intervals
        let durations = intervals.map(\.duration)
        let roundLength = durations.reduce(.zero, +)
        let index = min(engine.activeTimerIndex, max(intervals.count - 1, 0))
        let current = durations.indices.contains(index) ? durations[index] : .zero

        // Odběhnutá část aktivního intervalu a celého tréninku:
        // dokončená kola + intervaly před aktivním + část aktivního intervalu.
        let intervalElapsed = max(current - engine.remainingTime, .zero)
        let elapsed = roundLength * max(engine.finishedRounds - 1, 0)
            + durations[..<min(index, durations.count)].reduce(.zero, +)
            + intervalElapsed

        // Úvodní odpočet 3-2-1 posouvá začátky do budoucnosti – systémové
        // odpočty do té doby stojí na plné délce.
        let leadIn = engine.isCountingDown ? TimeInterval(engine.countdownValue) : 0
        let intervalStart = now.addingTimeInterval(leadIn - intervalElapsed.timeInterval)
        let start = now.addingTimeInterval(leadIn - elapsed.timeInterval)
        let end = engine.rounds > 0
            ? start.addingTimeInterval((roundLength * engine.rounds).timeInterval)
            : nil

        let name = intervals.indices.contains(index) ? intervals[index].name : ""

        return TimerActivityAttributes.ContentState(
            phase: engine.isRunning ? .running : .paused,
            intervalName: name,
            intervalStart: intervalStart,
            intervalEnd: intervalStart.addingTimeInterval(current.timeInterval),
            start: start,
            end: end,
            pausedAt: engine.isRunning ? nil : now
        )
    }
}

private extension Duration {
    var timeInterval: TimeInterval {
        Double(components.seconds) + Double(components.attoseconds) / 1e18
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
    private func persist(_ newSettings: TimerSettings) {
        guard let context = modelContext else { return }

        TimerData.mainTimer(in: context).settings = newSettings
        do {
            try context.save()
        } catch {
            print("Chyba při ukládání časovačů: \(error)")
        }
    }

    /// Uloží intervaly upravené přes engine (addTimer/removeTimer).
    private func persistIntervals() {
        var updated = settings
        updated.intervals = timers
        settings = updated
        persist(updated)
    }
}
