//
//  TimeDisplayFormat.swift
//  GustavTimer
//
//  Created by Dalibor Janeček on 26.07.2025.
//
//  Určuje, jak se zobrazuje zbývající čas na displeji.
//  Používá se jak na iPhone (portrait vs. landscape), tak na Apple Watch.
//
//  Tři režimy:
//
//      .seconds                    →  "45"         nebo  "120"
//      .minutesSeconds             →  "0:45"       nebo  "2:00"
//      .minutesSecondsHundredths   →  "45.32"      nebo  "2:00.05"
//
//  Příklad použití v TimerEngine:
//
//      engine.formattedCurrentTime(format: .seconds)                   // "45"
//      engine.formattedCurrentTime(format: .minutesSeconds)            // "0:45"
//      engine.formattedCurrentTime(format: .minutesSecondsHundredths)  // "45.32"
//
//  Příklad použití s @AppStorage (persistence uživatelské volby):
//
//      @AppStorage("portraitTimeDisplayFormat") var format: TimeDisplayFormat = .seconds
//
//  Na iPhone si uživatel formát přepíná swipem přes odpočet (stránkovaný
//  TabView), pro každou orientaci zvlášť:
//      - Portrait  → .seconds (výchozí, velké číslo) ↔ .minutesSeconds
//      - Landscape → .minutesSecondsHundredths (výchozí, přesný čas
//                    pro závodníky) ↔ .seconds
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

    /// Zobrazí minuty:sekundy: "2:00", "0:45".
    /// Celé sekundy jako `.seconds`, jen rozepsané na minuty.
    case minutesSeconds = "minutesSeconds"

    /// Zobrazí minuty:sekundy.setiny: "2:00.05", "0:45.32".
    /// Vhodné pro přesné měření a landscape režim.
    case minutesSecondsHundredths = "minutesSecondsHundredths"

    /// Lidsky čitelný název formátu (pro UI settingů).
    var displayName: String {
        switch self {
        case .seconds:
            return "Seconds"
        case .minutesSeconds:
            return "Minutes:Seconds"
        case .minutesSecondsHundredths:
            return "Minutes:Seconds.Hundredths"
        }
    }
}
