//
//  TimerSettings.swift
//  GustavTimer
//
//  Created by Dalibor Janeček on 14.09.2026.
//
//  Kompletní nastavení jednoho timeru jako hodnotový typ.
//  Závisí pouze na Foundation – žádné SwiftData, SwiftUI ani UIKit,
//  aby se dal použít na Apple Watch, v testech i při skládání sdíleného odkazu.
//
//  Tohle je jediné místo, kde je napsané, co všechno „timer“ obnáší.
//  Přidání dalšího nastavení = jedno pole tady; kompilátor pak ukáže všechna
//  místa, která se musí dopsat (persistence, sdílený odkaz, engine).
//
//  Tok dat v aplikaci:
//
//      TimerData (SwiftData)  ──.settings──▶  TimerSettings  ──apply()──▶  TimerEngine
//             ▲                                     │
//             └───────────── .settings = ───────────┘
//
//  Příklady:
//
//      // Výběr oblíbeného timeru – jedním přiřazením, nikdy po polích
//      mainTimer.settings = favourite.settings
//
//      // Sdílený odkaz přebije jen to, co skutečně nese
//      let merged = link.applied(to: mainTimer.settings)
//

import Foundation

/// Kompletní nastavení jednoho timeru.
struct TimerSettings: Equatable, Codable, Sendable {

    /// Název timeru. Délku omezuje UI na `AppConfig.maxTimerName`.
    var name: String

    /// Intervaly v pořadí jednoho kola.
    var intervals: [IntervalData]

    /// Počet opakování celého kola. `-1` = nekonečno.
    var rounds: Int

    /// Zvuk přechodu mezi intervaly. `nil` = ztlumeno.
    ///
    /// Tohle je jediná reprezentace „zvuk zapnutý / vypnutý“. Samostatný
    /// příznak `isSoundEnabled` (do verze 2.3 v UserDefaults) už neexistuje –
    /// držel se ručně v synchronizaci na třech místech a rozcházel se.
    var sound: SoundModel?

    /// Haptická odezva při přechodu intervalu, konci kola a konci timeru.
    var isVibrating: Bool

    /// Tikání při každé uplynulé sekundě.
    var isTicking: Bool

    /// Odpočet 3-2-1 před prvním kolem.
    var hasCountdown: Bool

    init(
        name: String,
        intervals: [IntervalData],
        rounds: Int,
        sound: SoundModel?,
        isVibrating: Bool,
        isTicking: Bool,
        hasCountdown: Bool
    ) {
        self.name = name
        self.intervals = intervals
        self.rounds = rounds
        self.sound = sound
        self.isVibrating = isVibrating
        self.isTicking = isTicking
        self.hasCountdown = hasCountdown
    }

    /// Výchozí timer nové instalace.
    static let `default` = TimerSettings(
        name: "Gustav Timer",
        intervals: [
            IntervalData(value: 60, name: "Work"),
            IntervalData(value: 30, name: "Rest")
        ],
        rounds: -1,
        sound: .beep,
        isVibrating: false,
        isTicking: false,
        hasCountdown: true
    )

    /// Shoda „je to tentýž trénink“ – porovná všechno kromě názvu.
    ///
    /// Používá se pro hvězdičku „už uloženo“ v toolbaru a pro zvýraznění
    /// vybraného timeru v oblíbených. Název se schválně vynechává: po uložení
    /// mezi oblíbené dostane záznam jméno od uživatele, ale jde pořád o tentýž
    /// trénink.
    ///
    ///     var renamed = settings
    ///     renamed.name = "PONDĚLÍ"
    ///     settings.matchesWorkout(of: renamed)  // true
    func matchesWorkout(of other: TimerSettings) -> Bool {
        var lhs = self
        var rhs = other
        lhs.name = ""
        rhs.name = ""
        return lhs == rhs
    }
}
