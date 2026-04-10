//
//  AchievementModel.swift
//  GustavTimer
//

import Foundation

enum AchievementCategory: String, Codable {
    case milestone
    case rounds
    case dedication
    case workout
}

struct Achievement: Identifiable, Codable, Equatable {
    let id: String
    let nameKey: String
    let descriptionKey: String
    let icon: String
    let category: AchievementCategory

    static func == (lhs: Achievement, rhs: Achievement) -> Bool {
        lhs.id == rhs.id
    }
}

extension Achievement {
    static let all: [Achievement] = [
        // MARK: Milníky
        Achievement(
            id: "first_timer",
            nameKey: "ACH_FIRST_TIMER_NAME",
            descriptionKey: "ACH_FIRST_TIMER_DESC",
            icon: "flag.fill",
            category: .milestone
        ),
        Achievement(
            id: "five_timers",
            nameKey: "ACH_FIVE_TIMERS_NAME",
            descriptionKey: "ACH_FIVE_TIMERS_DESC",
            icon: "hand.raised.fill",
            category: .milestone
        ),
        Achievement(
            id: "twenty_five_timers",
            nameKey: "ACH_TWENTY_FIVE_TIMERS_NAME",
            descriptionKey: "ACH_TWENTY_FIVE_TIMERS_DESC",
            icon: "star.fill",
            category: .milestone
        ),
        Achievement(
            id: "hundred_timers",
            nameKey: "ACH_HUNDRED_TIMERS_NAME",
            descriptionKey: "ACH_HUNDRED_TIMERS_DESC",
            icon: "crown.fill",
            category: .milestone
        ),
        // MARK: Kola
        Achievement(
            id: "ten_rounds",
            nameKey: "ACH_TEN_ROUNDS_NAME",
            descriptionKey: "ACH_TEN_ROUNDS_DESC",
            icon: "arrow.circlepath",
            category: .rounds
        ),
        Achievement(
            id: "hundred_rounds",
            nameKey: "ACH_HUNDRED_ROUNDS_NAME",
            descriptionKey: "ACH_HUNDRED_ROUNDS_DESC",
            icon: "figure.run",
            category: .rounds
        ),
        Achievement(
            id: "five_hundred_rounds",
            nameKey: "ACH_FIVE_HUNDRED_ROUNDS_NAME",
            descriptionKey: "ACH_FIVE_HUNDRED_ROUNDS_DESC",
            icon: "bolt.fill",
            category: .rounds
        ),
        // MARK: Odhodlání
        Achievement(
            id: "no_stop",
            nameKey: "ACH_NO_STOP_NAME",
            descriptionKey: "ACH_NO_STOP_DESC",
            icon: "lock.fill",
            category: .dedication
        ),
        Achievement(
            id: "three_clean",
            nameKey: "ACH_THREE_CLEAN_NAME",
            descriptionKey: "ACH_THREE_CLEAN_DESC",
            icon: "flame.fill",
            category: .dedication
        ),
        // MARK: Workout
        Achievement(
            id: "ten_rounds_session",
            nameKey: "ACH_TEN_ROUNDS_SESSION_NAME",
            descriptionKey: "ACH_TEN_ROUNDS_SESSION_DESC",
            icon: "medal.fill",
            category: .workout
        ),
        Achievement(
            id: "favorite_ten",
            nameKey: "ACH_FAVORITE_TEN_NAME",
            descriptionKey: "ACH_FAVORITE_TEN_DESC",
            icon: "heart.fill",
            category: .workout
        ),
    ]
}
