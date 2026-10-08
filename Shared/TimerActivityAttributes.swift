//
//  TimerActivityAttributes.swift
//  GustavTimer
//
//  Sdílený model Live Activity – kompiluje se do aplikace i do widget extension,
//  proto nesmí sahat na nic z app targetu (AppConfig, TimerViewModel, …).
//
//  Live Activity se sama nepřekresluje a aktualizaci jí umí poslat jen běžící
//  aplikace – ta ale na pozadí neběží, systém ji uspí. Stav proto nese časy jako
//  absolutní data a odpočty z nich systém vykresluje sám (`Text(timerInterval:)`):
//
//  - Aktuální interval platí jen do `intervalEnd`. Další přechod pošle aplikace,
//    pokud ještě žije; když ne, aktivita je od `intervalEnd` stale a dlaždice
//    místo intervalu ukáže čas celého tréninku.
//  - Začátek a konec celého tréninku platí i po hodině bez jediné aktualizace.
//

import Foundation

#if canImport(ActivityKit)
import ActivityKit

struct TimerActivityAttributes: ActivityAttributes {

    struct ContentState: Codable, Hashable {

        enum Phase: String, Codable, Hashable {
            /// Timer běží.
            case running
            /// Uživatel timer pozastavil.
            case paused
        }

        var phase: Phase

        // MARK: Aktuální interval

        /// Název aktuálního intervalu („Work“, „Rest“…).
        var intervalName: String

        /// Začátek aktuálního intervalu posunutý o pauzy. Během úvodního
        /// odpočtu 3-2-1 leží v budoucnosti.
        var intervalStart: Date

        /// Konec aktuálního intervalu. Zároveň `staleDate` aktivity.
        var intervalEnd: Date

        // MARK: Celý trénink

        /// Začátek tréninku posunutý o čas strávený v pauze – tedy `teď − uplynulý čas`.
        /// Během úvodního odpočtu 3-2-1 leží v budoucnosti.
        var start: Date

        /// Konec tréninku. `nil` = nekonečný počet kol, dlaždice pak místo
        /// zbývajícího času ukazuje uplynulý.
        var end: Date?

        /// Okamžik pauzy. Systémové odpočty se na něm zastaví.
        var pausedAt: Date?
    }

    // Bez vlastností: dlaždice neukazuje ani název timeru.
}

extension TimerActivityAttributes.ContentState {

    /// Trénink má konečný počet kol – odpočítává se zbývající čas.
    var isCountingDown: Bool { end != nil }

    /// Rozsah pro odpočet aktuálního intervalu.
    var intervalRange: ClosedRange<Date> {
        intervalStart...max(intervalStart, intervalEnd)
    }

    /// Rozsah pro `Text(timerInterval:)` celého tréninku. U nekonečného tréninku
    /// stačí horní mez dost daleko – zobrazuje se uplynulý čas a ten k ní nikdy
    /// nedojde.
    var timerRange: ClosedRange<Date> {
        let upper = end ?? start.addingTimeInterval(7 * 24 * 3600)
        return start...max(start, upper)
    }
}
#endif
