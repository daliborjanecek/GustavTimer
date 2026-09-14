//
//  TimerActivityAttributes.swift
//  GustavTimer
//
//  Sdílený model Live Activity – kompiluje se do aplikace i do widget extension,
//  proto nesmí sahat na nic z app targetu (AppConfig, TimerViewModel, …).
//
//  Záměrně holý. Live Activity se sama nepřekresluje a aktualizaci jí umí poslat
//  jen běžící aplikace – ta ale na pozadí neběží, systém ji uspí. Cokoli, co by
//  se muselo průběžně měnit (odpočet, interval, kolo, konec tréninku), by proto
//  na obrazovce zamrzlo a lhalo. Stav tedy nese jedinou věc: jestli timer běží,
//  nebo je pozastavený. Zbytek si uživatel najde v aplikaci.
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
    }

    // Bez vlastností: dlaždice neukazuje ani název timeru – nic, co by se dalo
    // splést s aktuálním stavem tréninku.
}
#endif
