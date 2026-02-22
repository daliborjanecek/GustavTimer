//
//  WorkoutManager.swift
//  GustavTimer
//
//  Created by Dalibor Janeček on 21.02.2026.
//


import HealthKit
import Combine

class WorkoutManager: NSObject, ObservableObject {
    let healthStore = HKHealthStore()
    var session: HKWorkoutSession?
    var builder: HKLiveWorkoutBuilder?
    
    @Published var isWorkoutActive = false
    
    // Požádat o oprávnění (zavolat při prvním spuštění)
    func requestAuthorization() {
        let typesToShare: Set = [HKQuantityType.workoutType()]
        let typesToRead: Set = [HKQuantityType.workoutType()]
        
        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { success, error in
            if let error = error {
                print("HealthKit authorization failed: \(error)")
            }
        }
    }
    
    // Spustit workout session (zavolat když začíná timer)
    func startWorkout() {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .other // nebo .crossTraining
        configuration.locationType = .indoor
        
        do {
            session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            builder = session?.associatedWorkoutBuilder()
            
            session?.delegate = self
            builder?.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)
            
            session?.startActivity(with: Date())
            builder?.beginCollection(withStart: Date()) { [weak self] success, error in
                DispatchQueue.main.async {
                    self?.isWorkoutActive = success
                }
                if let error = error {
                    print("Failed to begin collection: \(error)")
                }
            }
        } catch {
            print("Failed to start workout: \(error)")
        }
    }
    
    // Ukončit workout session (zavolat když timer končí)
    func endWorkout() {
        session?.end()
        builder?.endCollection(withEnd: Date()) { [weak self] success, error in
            DispatchQueue.main.async {
                self?.isWorkoutActive = false
            }
            self?.builder?.finishWorkout { workout, error in
                // Workout uložen do HealthKit
            }
        }
    }
}

// MARK: - HKWorkoutSessionDelegate
extension WorkoutManager: HKWorkoutSessionDelegate {
    func workoutSession(_ workoutSession: HKWorkoutSession,
                       didChangeTo toState: HKWorkoutSessionState,
                       from fromState: HKWorkoutSessionState,
                       date: Date) {
        DispatchQueue.main.async {
            self.isWorkoutActive = (toState == .running)
        }
    }
    
    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("Workout session failed: \(error)")
    }
}
