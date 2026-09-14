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

        engine.onStart = {
            UIApplication.shared.isIdleTimerDisabled = true
        }

        engine.onStop = { [weak self] in
            UIApplication.shared.isIdleTimerDisabled = false
            self?.stopCounter += 1
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
        let limits = SharedTimerLink.Limits(
            maxIntervalCount: AppConfig.maxTimerCount,
            maxIntervalValue: AppConfig.maxTimerValue,
            maxRounds: AppConfig.roundsOptions.last ?? 31
        )

        guard let link = SharedTimerLink.parse(items: items, limits: limits) else { return }

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
