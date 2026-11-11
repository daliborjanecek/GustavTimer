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

    /// Timer z odkazu (zvenku i z banneru), který čeká na potvrzení uživatele.
    /// `TimerView` na něj reaguje dotazem (`SharedLinkPrompt`) a podle
    /// odpovědi zavolá `confirmPendingSharedLink()` nebo
    /// `declinePendingSharedLink()`. Do té doby se timer nemění.
    @Published private(set) var pendingSharedLink: PendingSharedLink?

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

    // MARK: - Analytika tréninku

    /// Rozběhnutý trénink – od prvního startu do dokončení nebo resetu.
    /// Pauza ho neukončí, takže `timer.stopped` znamená opravdu vzdaný trénink.
    private struct WorkoutSession {
        let startedAt: Date
        let settings: TimerSettings
        let origin: TimerOrigin
        let presetID: String?
    }

    private var session: WorkoutSession?

    /// Nastavení z posledního načteného odkazu. Podle něj `timer.started`
    /// pozná, že trénink přišel z odkazu. Drží se jen v paměti.
    private var lastLinkSettings: TimerSettings?

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
                self.trackSessionCompleted()
                if self.completedTimerCount % AppConfig.reviewPromptInterval == 0 {
                    Analytics.send(.reviewRequested, parameters: [
                        "completed_count": String(self.completedTimerCount)
                    ])
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                        self?.onReviewRequested?()
                    }
                }
            case .countdownTick:
                self.vibrate()
            case .countdownEnd:
                self.vibrateRound()
            case .secondTick(let remainingSeconds):
                self.playTickSound(remainingSeconds: remainingSeconds)
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
        if resetCurrentState { trackSessionAbandoned(reason: "settings") }
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
        trackSessionAbandoned(reason: "reset")
        engine.reset()
    }

    func skipLap() {
        engine.skipCurrentInterval()
    }

    // MARK: - Formátování času

    func formattedCurrentTime(timeDisplayFormat: TimeDisplayFormat) -> String {
        engine.formattedCurrentTime(format: timeDisplayFormat)
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
            // Přechod je „nultá“ sekunda, takže tiká v obou režimech tikání.
            playTickSound(remainingSeconds: 0)
        }
    }

    /// Tik, pokud ho režim tikání pro danou sekundu odpočtu chce.
    ///
    ///     .everySecond  → tiká vždy
    ///     .finalSeconds → tiká jen při 3, 2, 1 (a na přechodu při ztlumeném zvuku)
    private func playTickSound(remainingSeconds: Int) {
        guard settings.ticking.shouldTick(remainingSeconds: remainingSeconds) else { return }
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
    ///
    /// - Parameter fromApp: odkaz otevřený z obsahu aplikace (banner) přes
    ///   `AppLinkRouter`, ne zvenku. Nepočítá se jako akvizice.
    func handleDeepLink(url: URL, fromApp: Bool = false) {
        switch SharedTimerLink.route(url: url) {
        case .whatsNew:
            showingWhatsNew = true
        case .screen(let screen):
            // Nastavení otevře TimerView, obrazovku v něm SettingsView.
            AppNavigator.shared.open(screen)
        case .sharedTimer(let items):
            guard let link = SharedTimerLink.parse(items: items, limits: AppConfig.sharedLinkLimits) else {
                // Odkaz bez platného intervalu – timer se nemění, není se na co ptát.
                trackSharedLinkOpened(url: url, items: items, link: nil, fromApp: fromApp, prompt: nil)
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
        trackSharedLinkOpened(url: pending.url, items: pending.items, link: pending.link, fromApp: pending.fromApp, prompt: true)
    }

    /// Uživatel načtení timeru z odkazu odmítl – nic se nemění.
    func declinePendingSharedLink() {
        guard let pending = pendingSharedLink else { return }
        pendingSharedLink = nil
        trackSharedLinkOpened(url: pending.url, items: pending.items, link: pending.link, fromApp: pending.fromApp, prompt: false)
    }

    /// `timer.link_opened` – otevření sdíleného odkazu.
    ///
    /// `source` je kanál, kterým odkaz odesílatel poslal (`utm_source`, zapisuje
    /// ho share sheet aplikace). Odkazy ze starších verzí ho nenesou, ty prozradí
    /// `link_type` (custom schéma = verze 2.2.1) a `has_settings` (bez zvuku
    /// a vibrací = verze před 2.4). `loaded` je `false`, když odkaz neobsahoval
    /// jediný platný interval nebo ho uživatel odmítl načíst – timer se
    /// nezměnil. Odkaz z banneru v aplikaci má `link_type=in_app`.
    ///
    /// - Parameter prompt: odpověď na dotaz před načtením – `true` načíst,
    ///   `false` odmítnout, `nil` = dotaz nebyl (neplatný odkaz). Jde do
    ///   parametru `prompt` (`accepted` / `declined` / `none`).
    private func trackSharedLinkOpened(url: URL, items: [URLQueryItem], link: SharedTimerLink?, fromApp: Bool, prompt: Bool?) {
        let source = SharedTimerLink.trackingValue(for: SharedTimerLink.sourceKey, in: items) ?? "unknown"
        let linkType = fromApp ? "in_app" : (url.scheme?.lowercased() == "https" ? "universal" : "scheme")
        let loaded = link != nil && prompt != false
        var parameters = [
            "link_type": linkType,
            "source": source,
            "loaded": loaded ? "true" : "false",
            "prompt": prompt.map { $0 ? "accepted" : "declined" } ?? "none"
        ]
        if let campaign = SharedTimerLink.trackingValue(for: SharedTimerLink.campaignKey, in: items) {
            parameters["campaign"] = campaign
        }
        if let link {
            parameters["interval_pattern"] = Analytics.intervalPattern(link.intervals)
            parameters["has_settings"] = Analytics.boolValue(link.sound != nil)
        }

        Analytics.send(.linkOpened, parameters: parameters)

        if link != nil {
            if !fromApp {
                AnalyticsAcquisition.reportLinkIfEligible(channel: source)
            }
        } else {
            TelemetryDeck.errorOccurred(id: "link.invalid", category: .userInput)
        }
    }

    /// Načte timer ze sdíleného odkazu, který uživatel potvrdil, a otevře
    /// nastavení, ať ho hned vidí.
    ///
    /// Odkaz bez jediného platného intervalu sem nedojde – `parse` vrátí
    /// `nil` a stávající timer, počet kol ani uložená data se nezmění.
    private func load(_ link: SharedTimerLink) {
        // Odkaz přepíše rozběhnutý trénink – započítat ho dřív, než zmizí.
        trackSessionAbandoned(reason: "link")

        // Odkaz přebije jen to, co skutečně nese. Odkaz z verze 2.2/2.3
        // neobsahuje zvuk ani vibrace, takže si uživatel nechá svoje.
        let merged = link.applied(to: settings)

        apply(merged, resetState: true)
        // Timer z odkazu v oblíbených není – aktivní timer se od oblíbeného odpojí.
        persist(merged, detachingSource: true)
        lastLinkSettings = merged

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.showingSheet = true
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
// Trychtýř: timer.started (is_resume=false) → timer.completed, nebo
// timer.stopped (vzdaný trénink). Pauza a pokračování trénink nekončí.
extension TimerViewModel {

    /// `timer.started`. První start zahájí trénink a určí jeho původ,
    /// pokračování po pauze nese `is_resume=true`.
    private func trackStart(input: TimerInput) {
        // finishedRounds je číslo běžícího kola, před prvním startem 0.
        let isResume = engine.finishedRounds > 0
        if !isResume || session == nil {
            let (origin, presetID) = resolveOrigin(of: settings)
            session = WorkoutSession(startedAt: .now, settings: settings, origin: origin, presetID: presetID)
        }

        var parameters = Analytics.parameters(for: settings)
        parameters["input"] = input.rawValue
        parameters["is_resume"] = Analytics.boolValue(isResume)
        addOrigin(to: &parameters)
        Analytics.send(.timerStarted, parameters: parameters)
    }

    /// `timer.completed` – trénink doběhl do konce. `floatValue` je reálná
    /// doba od prvního startu včetně pauz, v sekundách.
    private func trackSessionCompleted() {
        guard let session else { return }

        var parameters = Analytics.parameters(for: session.settings)
        parameters["completed_count"] = String(completedTimerCount)
        addOrigin(to: &parameters)
        Analytics.send(.timerCompleted, parameters: parameters, floatValue: Date.now.timeIntervalSince(session.startedAt))
        TelemetryDeck.coreFeatureUsed(featureName: "timer_completed")

        self.session = nil
    }

    /// `timer.stopped` – rozběhnutý trénink skončil dřív, než doběhl.
    /// Volat před resetem enginu, jinak se ztratí, kde uživatel skončil.
    ///
    /// - Parameter reason: `reset` (tlačítko), `settings` (zavření nastavení
    ///   s resetem), `link` (přepsání odkazem).
    private func trackSessionAbandoned(reason: String) {
        guard let session else { return }
        self.session = nil

        let progress = Analytics.workoutProgress(
            intervals: session.settings.intervals,
            rounds: session.settings.rounds,
            round: engine.finishedRounds,
            activeIndex: engine.activeTimerIndex,
            remainingSeconds: Double(engine.remainingTime.components.seconds)
                + Double(engine.remainingTime.components.attoseconds) / 1e18
        )

        var parameters = Analytics.parameters(for: session.settings)
        parameters["reason"] = reason
        parameters["round"] = String(engine.finishedRounds)
        parameters["elapsed"] = Analytics.durationBucket(seconds: progress.elapsed)
        parameters["progress_pct"] = progress.fraction.map(Analytics.percentBucket) ?? "loop"
        addOrigin(to: &parameters)
        Analytics.send(.timerStopped, parameters: parameters, floatValue: progress.elapsed)
    }

    private func addOrigin(to parameters: inout [String: String]) {
        guard let session else { return }
        parameters["timer_origin"] = session.origin.rawValue
        if let presetID = session.presetID {
            parameters["preset"] = presetID
        }
    }

    private func resolveOrigin(of settings: TimerSettings) -> (TimerOrigin, String?) {
        let favourites = (try? modelContext?.fetch(FetchDescriptor<TimerData>()))?
            .filter { $0.order != AppConfig.mainTimerOrder }
            .map(\.settings) ?? []

        return Analytics.origin(
            of: settings,
            presets: PredefinedTimer.allCases.map { (id: $0.rawValue, settings: $0.settings) },
            favourites: favourites,
            lastLink: lastLinkSettings
        )
    }
}
