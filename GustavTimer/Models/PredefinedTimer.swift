//
//  PredefinedTimer.swift
//  GustavTimer
//
//  Created by Dalibor Janeček on 25.02.2026.
//
//  Předdefinované presety. Nejsou v databázi – dokud si je uživatel
//  nevybere, existují jen jako hodnoty.
//

import Foundation

enum PredefinedTimer: String, CaseIterable, Identifiable {
    case fiveMeditation, tabata, emom10Min, hiit, amrap

    var id: String {
        self.rawValue
    }

    var settings: TimerSettings {
        switch self {
        case .fiveMeditation:
            return TimerSettings(
                name: String(localized: "PT_5MIN_MEDITATION"),
                intervals: [IntervalData(value: 300, name: String(localized: "LAP_MEDITATION"))],
                rounds: -1,
                sound: .gong,
                isVibrating: false,
                isTicking: false,
                hasCountdown: true
            )

        case .tabata:
            return TimerSettings(
                name: String(localized: "PT_TABATA"),
                intervals: [
                    IntervalData(value: 20, name: String(localized: "LAP_WORK")),
                    IntervalData(value: 10, name: String(localized: "LAP_REST"))
                ],
                rounds: 8,
                sound: .bicycle,
                isVibrating: true,
                isTicking: false,
                hasCountdown: true
            )

        case .emom10Min:
            return TimerSettings(
                name: String(localized: "PT_EMOM_10MIN"),
                intervals: [IntervalData(value: 60, name: String(localized: "LAP_WORK"))],
                rounds: 10,
                sound: .whistle,
                isVibrating: true,
                isTicking: false,
                hasCountdown: true
            )

        case .hiit:
            return TimerSettings(
                name: String(localized: "PT_HIIT"),
                intervals: [
                    IntervalData(value: 30, name: String(localized: "LAP_SPRINT")),
                    IntervalData(value: 15, name: String(localized: "LAP_REST"))
                ],
                rounds: 10,
                sound: .whistle,
                isVibrating: true,
                isTicking: false,
                hasCountdown: true
            )

        case .amrap:
            return TimerSettings(
                name: String(localized: "PT_AMRAP"),
                intervals: [IntervalData(value: 60, name: String(localized: "LAP_MAX"))],
                rounds: 20,
                sound: .beep,
                isVibrating: true,
                isTicking: false,
                hasCountdown: true
            )
        }
    }

    var description: [String] {
        switch self {
        case .fiveMeditation: return [String(localized: "PT_5MIN_MEDITATION_TIP1"), String(localized: "PT_5MIN_MEDITATION_TIP2"), String(localized: "PT_5MIN_MEDITATION_TIP3")]
        case .tabata: return [String(localized: "PT_TABATA_TIP1"), String(localized: "PT_TABATA_TIP2"), String(localized: "PT_TABATA_TIP3")]
        case .emom10Min: return [String(localized: "PT_EMOM_10MIN_TIP1"), String(localized: "PT_EMOM_10MIN_TIP2"), String(localized: "PT_EMOM_10MIN_TIP3")]
        case .hiit: return [String(localized: "PT_HIIT_TIP1"), String(localized: "PT_HIIT_TIP2"), String(localized: "PT_HIIT_TIP3")]
        case .amrap: return [String(localized: "PT_AMRAP_TIP1"), String(localized: "PT_AMRAP_TIP2"), String(localized: "PT_AMRAP_TIP3")]
        }
    }
}
