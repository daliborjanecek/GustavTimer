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

    // MARK: - iOS-specific publikované vlastnosti
    @Published var showingSheet = false
    @Published var showingWhatsNew: Bool = false
    @Published var editMode = EditMode.inactive
    @Published var startedFromDeeplink: Bool = false

    // MARK: Lottie animation state
    @Published var appearanceIconAnimation = LottiePlaybackMode.paused(at: .frame(0))
    @Published var loopIconAnimation = LottiePlaybackMode.paused(at: .frame(0))

    // MARK: - Nastavení (AppStorage)
    @AppStorage("rounds") var rounds: Int = -1
    @AppStorage("stopCounter") var stopCounter: Int = 0
    @AppStorage("completedTimerCount") var completedTimerCount: Int = 0

    // MARK: - Review prompt
    var onReviewRequested: (() -> Void)?
    @AppStorage("whatsNewVersion") var whatsNewVersion: Int = 0
    @AppStorage("isSoundEnabled") var isSoundEnabled: Bool = true
    @AppStorage("isVibrating") var isVibrating: Bool = false
    @AppStorage("timeDisplayFormat") var timeDisplayFormat: TimeDisplayFormat = .seconds

    // MARK: - Soukromé vlastnosti
    private var sound: SoundModel?
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
        syncRoundsToEngine()
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

        // Sleduj změny v rounds a synchronizuj s engine
        // (didSet se nevolá při změně z jiné @AppStorage instance)
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .compactMap { [weak self] _ in self?.rounds }
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] newValue in
                self?.engine.rounds = newValue
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

    private func syncRoundsToEngine() {
        engine.rounds = rounds
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
        startedFromDeeplink = false
        UserDefaults.standard.set(false, forKey: "startedFromDeeplink")
    }

    func skipLap() {
        engine.skipCurrentInterval()
    }

    // MARK: - Správa intervalů

    func addTimer() {
        engine.addInterval()
        saveTimers()
    }

    func removeTimer(at offsets: IndexSet) {
        engine.removeInterval(at: offsets)
        saveTimers()
    }

    func removeTimer(index: Int) {
        engine.removeInterval(at: index)
        saveTimers()
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

    // MARK: - Nastavení zvuku

    func setSound(sound: SoundModel?) {
        isSoundEnabled = sound != nil
        self.sound = sound
    }

    /// Zobrazení/skrytí nastavení
    func toggleSheet() {
        showingSheet.toggle()
        stopTimer()
        resetTimer()
    }

    // MARK: - Zpětná vazba (vibrace a zvuky) – iOS specific

    private func vibrate() {
        guard isVibrating && engine.isRunning else { return }
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    private func vibrateRound() {
        guard isVibrating && engine.isRunning else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    private func vibrateEnd() {
        guard isVibrating else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }

    private func playSound() {
        guard isSoundEnabled else { return }
        if let sound {
            SoundManager.instance.playSound(soundModel: sound)
        }
    }

    // MARK: - Co je nového
    func showWhatsNew() {
        if whatsNewVersion < AppConfig.version {
            showingWhatsNew = true
            whatsNewVersion = AppConfig.version
        }
    }

    // MARK: - Deep Links
    func handleDeepLink(url: URL) {
        guard url.scheme == "gustavtimerapp",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              let host = components.host else { return }

        switch host {
        case "whatsnew":
            showingWhatsNew = true
        case "timer":
            handleTimerDeepLink(components: components)
        default:
            print("Neznámý deep link: \(host)")
        }
    }

    private func handleTimerDeepLink(components: URLComponents) {
        let originalTimers = timers
        var newTimers: [IntervalData] = []
        var newRounds: Int? = nil

        if let queryItems = components.queryItems {
            for item in queryItems {
                // Rezervované klíčové slovo "rounds" – nastavuje počet opakování
                if item.name.lowercased() == "rounds" {
                    if let value = item.value, let intValue = Int(value) {
                        if intValue == -1 {
                            newRounds = -1
                        } else {
                            newRounds = max(1, min(AppConfig.roundsOptions.last ?? 31, intValue))
                        }
                    }
                    continue
                }

                // Plný formát: name=value → pojmenovaný interval
                if let value = item.value, let intValue = Int(value),
                   intValue > 0, intValue <= AppConfig.maxTimerValue {
                    newTimers.append(IntervalData(value: intValue, name: item.name))
                }
                // Minimalistický formát: jen číslo bez hodnoty → interval pojmenovaný jako "Kolo N"
                else if item.value == nil, let intValue = Int(item.name),
                        intValue > 0, intValue <= AppConfig.maxTimerValue {
                    let roundName = NSLocalizedString("ROUND", comment: "") + " \(newTimers.count + 1)"
                    newTimers.append(IntervalData(value: intValue, name: roundName))
                }

                // Nepřekročit maximální počet intervalů
                if newTimers.count >= AppConfig.maxTimerCount { break }
            }
        }

        if !newTimers.isEmpty {
            timers = newTimers
            // Pokud rounds není v URL → výchozí hodnota je nekonečno (-1)
            rounds = newRounds ?? -1
            startedFromDeeplink = true
            UserDefaults.standard.set(true, forKey: "startedFromDeeplink")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.showingSheet = true
            }
        } else {
            timers = originalTimers
        }
    }
}

// MARK: - Správa dat
extension TimerViewModel {
    private func loadTimers(resetCurrentState: Bool = true) {
        guard let context = modelContext else {
            engine.loadIntervals([
                IntervalData(value: 60, name: "Work"),
                IntervalData(value: 30, name: "Rest")
            ])
            return
        }

        do {
            let descriptor = FetchDescriptor<TimerData>(
                predicate: #Predicate<TimerData> { $0.order == 0 }
            )
            let timerDataArray = try context.fetch(descriptor)

            if let timerData = timerDataArray.first {
                engine.loadIntervals(timerData.intervals, resetState: resetCurrentState)
                engine.hasCountdown = timerData.hasCountdown
            } else {
                createAndSaveDefaultTimers()
            }
        } catch {
            print("Chyba při načítání časovačů: \(error)")
            engine.loadIntervals([
                IntervalData(value: 60, name: "Work"),
                IntervalData(value: 30, name: "Rest")
            ])
        }
    }

    private func saveTimers() {
        guard let context = modelContext else { return }

        do {
            let descriptor = FetchDescriptor<TimerData>(
                predicate: #Predicate<TimerData> { $0.order == 0 }
            )
            let timerDataArray = try context.fetch(descriptor)

            let timerData: TimerData
            if let existingData = timerDataArray.first {
                timerData = existingData
            } else {
                timerData = AppConfig.defaultTimer
                context.insert(timerData)
            }

            timerData.intervals = timers
            try context.save()
        } catch {
            print("Chyba při ukládání časovačů: \(error)")
        }
    }

    private func createAndSaveDefaultTimers() {
        engine.loadIntervals([
            IntervalData(value: 60, name: "Work"),
            IntervalData(value: 30, name: "Rest")
        ])
        saveTimers()
    }
}
