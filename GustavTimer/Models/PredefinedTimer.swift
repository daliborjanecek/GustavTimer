//
//  PredefinedTimer.swift
//  GustavTimer
//
//  Created by Dalibor Janeček on 25.02.2026.
//


enum PredefinedTimer: String, CaseIterable, Identifiable {
    case fiveMeditation, tabata, emom10Min, hiit, amrap
    
    var id: String {
        self.rawValue
    }

    var timer: TimerData {
        switch self {
        case .fiveMeditation: return AppConfig.predefinedTimers[0]
        case .tabata: return AppConfig.predefinedTimers[1]
        case .emom10Min: return AppConfig.predefinedTimers[2]
        case .hiit: return AppConfig.predefinedTimers[3]
        case .amrap: return AppConfig.predefinedTimers[4]
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
