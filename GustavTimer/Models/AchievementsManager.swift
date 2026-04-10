//
//  AchievementsManager.swift
//  GustavTimer
//

import Foundation
import SwiftUI

class AchievementsManager: ObservableObject {

    // MARK: - Perzistentní stav

    @AppStorage("totalRoundsCompleted") var totalRoundsCompleted: Int = 0
    @AppStorage("consecutiveTimersWithoutStop") var consecutiveTimersWithoutStop: Int = 0

    /// JSON-enkódovaný slovník [achievementId: unlockedAt]
    @AppStorage("unlockedAchievements") private var unlockedData: Data = Data()

    // MARK: - Publikované vlastnosti

    /// Právě odemčený achievement – řídí zobrazení toastu (nil = žádný toast)
    @Published var newlyUnlocked: Achievement? = nil

    // MARK: - Privátní stav

    private var unlocked: [String: Date] = [:]

    // MARK: - Init

    init() {
        unlocked = decode(unlockedData)
    }

    // MARK: - Veřejné metody

    func isUnlocked(_ id: String) -> Bool {
        unlocked[id] != nil
    }

    func unlockedDate(_ id: String) -> Date? {
        unlocked[id]
    }

    /// Zkontroluje podmínky všech achievementů a odemkne nové.
    /// Volá se z TimerViewModel při každém dokončení timeru.
    func checkAchievements(
        completedTimerCount: Int,
        finishedRounds: Int,
        stopsInSession: Int,
        maxUsedCount: Int
    ) {
        var toUnlock: [Achievement] = []

        for achievement in Achievement.all {
            guard !isUnlocked(achievement.id) else { continue }

            let shouldUnlock: Bool
            switch achievement.id {
            case "first_timer":
                shouldUnlock = completedTimerCount >= 1
            case "five_timers":
                shouldUnlock = completedTimerCount >= 5
            case "twenty_five_timers":
                shouldUnlock = completedTimerCount >= 25
            case "hundred_timers":
                shouldUnlock = completedTimerCount >= 100
            case "ten_rounds":
                shouldUnlock = totalRoundsCompleted >= 10
            case "hundred_rounds":
                shouldUnlock = totalRoundsCompleted >= 100
            case "five_hundred_rounds":
                shouldUnlock = totalRoundsCompleted >= 500
            case "no_stop":
                shouldUnlock = stopsInSession == 0
            case "three_clean":
                shouldUnlock = consecutiveTimersWithoutStop >= 3
            case "ten_rounds_session":
                shouldUnlock = finishedRounds >= 10
            case "favorite_ten":
                shouldUnlock = maxUsedCount >= 10
            default:
                shouldUnlock = false
            }

            if shouldUnlock {
                toUnlock.append(achievement)
            }
        }

        // Odemkni v pořadí a zobraz toast pro první nový
        for (index, achievement) in toUnlock.enumerated() {
            unlock(achievement, showToast: index == 0)
        }
    }

    // MARK: - Privátní metody

    private func unlock(_ achievement: Achievement, showToast: Bool) {
        unlocked[achievement.id] = Date()
        persist()
        if showToast {
            DispatchQueue.main.async {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    self.newlyUnlocked = achievement
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        self.newlyUnlocked = nil
                    }
                }
            }
        }
    }

    private func persist() {
        unlockedData = encode(unlocked)
    }

    private func encode(_ dict: [String: Date]) -> Data {
        (try? JSONEncoder().encode(dict)) ?? Data()
    }

    private func decode(_ data: Data) -> [String: Date] {
        (try? JSONDecoder().decode([String: Date].self, from: data)) ?? [:]
    }
}
