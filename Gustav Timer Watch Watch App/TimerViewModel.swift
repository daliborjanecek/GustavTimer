//
//  TimerViewModel.swift
//  GustavTimer
//
//  Created by Dalibor Janeček on 21.02.2026.
//

import SwiftUI
import Combine

class TimerViewModel: ObservableObject {

    // MARK: - Persistence
    @AppStorage("workInterval") private var workInterval: Int = 60
    @AppStorage("restInterval") private var restInterval: Int = 30

    let engine = TimerEngine(
        maxTimers: 5,
        maxCountdownValue: 300
    )
    
    let workoutManager = WorkoutManager()
    
    var timers: [IntervalData] {
        get { engine.intervals }
        set { engine.intervals = newValue }
    }

    var isTimerRunning: Bool { engine.isRunning }
    var activeTimerIndex: Int { engine.activeTimerIndex }
    var finishedRounds: Int { engine.finishedRounds }
    var count: Int { engine.count }
    var progress: Double { engine.progress }
    var isTimerFull: Bool { engine.isTimerFull }
    var activeIntervalName: String { timers[activeTimerIndex].name }
    var activeIntervalValue: Int { timers[activeTimerIndex].value }
    
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Inicializace
    init() {
        setupEngineCallbacks()
        bindEngineChanges()
        createDefaultTimers()
        workoutManager.requestAuthorization()
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
//        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
//            .compactMap { [weak self] _ in self?.rounds }
//            .removeDuplicates()
//            .receive(on: RunLoop.main)
//            .sink { [weak self] newValue in
//                self?.engine.rounds = newValue
//            }
//            .store(in: &cancellables)
    }
    
    func startStopTimer() {
        engine.startStop()
    }
    
    func resetTimer() {
        engine.reset()
    }
    
    func skipInterval() {
        engine.skipCurrentInterval()
    }
    
    func formattedCurrentTime(timeDisplayFormat: TimeDisplayFormat) -> String {
        engine.formattedCurrentTime(format: timeDisplayFormat)
    }
    
    func loadTimer(intervals: [IntervalData]) {
        engine.loadIntervals(intervals)
    }
    
    func loadSimpleTimer(_ first: Int, _ second: Int) {
        // Ulož do AppStorage
        workInterval = first
        restInterval = second

        // Načti do engine
        engine.loadIntervals([
            IntervalData(duration: .seconds(first), name: "Work"),
            IntervalData(duration: .seconds(second), name: "Rest")
        ])
    }

    /// Nastaví platform-specific callbacky na engine
    private func setupEngineCallbacks() {
        engine.onFeedback = { [weak self] feedback in
            guard let self else { return }
            switch feedback {
            case .intervalTransition:
                print("DEBUG: intervalTransition")
                WKInterfaceDevice.current().play(.directionUp)
//                self.vibrate()
//                self.playSound()
//                self.appearanceIconAnimation = .playing(
//                    .fromProgress(0, toProgress: 1, loopMode: .playOnce)
//                )
            case .roundComplete:
                print("DEBUG: roundComplete")
                WKInterfaceDevice.current().play(.success)

//                self.vibrateRound()
//                self.playSound()
//                self.loopIconAnimation = .playing(
//                    .fromProgress(0, toProgress: 1, loopMode: .playOnce)
//                )
            case .timerEnd:
                print("DEBUG: timerEnd")
//                self.vibrateEnd()
//                self.playSound()
            }
        }

        engine.onStart = { [weak self] in
            self?.workoutManager.startWorkout()
        }
        
        engine.onStop = { [weak self] in
            self?.workoutManager.endWorkout() // ← END workout session
        }
    }
    
    private func createDefaultTimers() {
        engine.loadIntervals([
            IntervalData(value: workInterval, name: "Work"),
            IntervalData(value: restInterval, name: "Rest")
        ])
    }
}
