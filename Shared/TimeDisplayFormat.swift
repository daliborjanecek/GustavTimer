//
//  TimeDisplayFormat.swift
//  GustavTimer
//
//  Created by Dalibor Janeček on 26.07.2025.
//
//  Určuje, jak se zobrazuje zbývající čas na displeji.
//  Používá se jak na iPhone (portrait vs. landscape), tak na Apple Watch.
//
//  Dva režimy:
//
//      .seconds                    →  "45"         nebo  "120"
//      .minutesSecondsHundredths   →  "0.45"       nebo  "2:00.00"
//
//  Příklad použití v TimerEngine:
//
//      engine.formattedCurrentTime(format: .seconds)                   // "45"
//      engine.formattedCurrentTime(format: .minutesSecondsHundredths)  // "0:45.32"
//
//  Příklad použití s @AppStorage (persistence uživatelské volby):
//
//      @AppStorage("timeDisplayFormat") var format: TimeDisplayFormat = .seconds
//
//  Na iPhone se formát přepíná podle orientace:
//      - Portrait  → .seconds (velké číslo)
//      - Landscape → .minutesSecondsHundredths (přesný čas pro závodníky)
//
//  Na Apple Watch bude pravděpodobně vždy .seconds kvůli malému displeji.
//

import Foundation

/// Formát zobrazení zbývajícího času.
/// Codable + RawValue(String) umožňuje přímé použití s @AppStorage.
enum TimeDisplayFormat: String, CaseIterable, Codable {

    /// Zobrazí pouze celé sekundy: "45", "120".
    /// Vhodné pro velký, dobře čitelný displej.
    case seconds = "seconds"

    /// Zobrazí minuty:sekundy.setiny: "2:00.05", "0:45.32".
    /// Vhodné pro přesné měření a landscape režim.
    case minutesSecondsHundredths = "minutesSecondsHundredths"

    /// Zobrazí pouze sekundy.setiny: "45.32", "120.05".
    /// Vhodné pro přesné zobrazení bez minut.
    case secondsHundredths = "secondsHundredths"

    /// Lidsky čitelný název formátu (pro UI settingů).
    var displayName: String {
        switch self {
        case .seconds:
            return "Seconds"
        case .minutesSecondsHundredths:
            return "Minutes:Seconds.Hundredths"
        case .secondsHundredths:
            return "Seconds.Hundredths"
        }
    }
}
