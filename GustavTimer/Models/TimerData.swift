//
//  TimerData.swift
//  GustavTimer
//
//  Created by Dalibor Janeček on 26.07.2025.
//
//  SwiftData obálka nad `TimerSettings`. Samotné nastavení timeru popisuje
//  `Shared/TimerSettings.swift` – tady se k němu přidává jen to, co dává smysl
//  jen v databázi: pořadí, datum vzniku a statistiky použití.
//
//  Nastavení se čte a zapisuje **vždy celé** přes `settings`. Kopírování po
//  jednotlivých polích bylo do verze 2.3 zdrojem chyb – při uložení oblíbeného
//  se ztrácel odpočet, při výběru počet kol.
//

import Foundation
import SwiftData
import SwiftUI

@Model
class TimerData {

    var id: UUID = UUID()
    var name: String
    var isVibrating: Bool
    var selectedSound: SoundModel?
    var rounds: Int
    var order: Int
    var createdAt: Date = Date()
    var usedCount: Int = 0
    var lastUsed: Date? = nil

    var hasCountdown: Bool = true

    /// Tikání každou sekundu. Do verze 2.3 žilo v UserDefaults, takže se
    /// neukládalo do oblíbených ani nepřenášelo odkazem. Default hodnota drží
    /// lightweight migraci schématu a zároveň odpovídá dosavadnímu chování
    /// uložených timerů (tikání jejich součástí nebylo).
    var isTicking: Bool = false

    var intervals: [IntervalData] = [
        IntervalData(value: 30, name: "Work"),
        IntervalData(value: 15, name: "Rest")
    ]

    init(order: Int, name: String, rounds: Int, selectedSound: SoundModel? = nil, isVibrating: Bool) {
        self.order = order
        self.name = name
        self.selectedSound = selectedSound
        self.isVibrating = isVibrating
        self.rounds = rounds
    }
    
    init(order: Int, name: String, rounds: Int, selectedSound: SoundModel? = nil, isVibrating: Bool, intervals: [IntervalData]) {
        self.order = order
        self.name = name
        self.selectedSound = selectedSound
        self.isVibrating = isVibrating
        self.rounds = rounds
        self.intervals = intervals
    }
    
    func selected() {
        usedCount += 1
        lastUsed = Date()
    }
}

// MARK: - Nastavení timeru

extension TimerData {

    /// Celé nastavení timeru jedním čtením/zápisem.
    ///
    ///     mainTimer.settings = favourite.settings   // místo pěti přiřazení
    ///
    /// Díky tomuhle neexistuje v aplikaci jediné místo, které by kopírovalo
    /// nastavení po polích – a tedy ani žádné, které by na některé pole zapomnělo.
    var settings: TimerSettings {
        get {
            TimerSettings(
                name: name,
                intervals: intervals,
                rounds: rounds,
                sound: selectedSound,
                isVibrating: isVibrating,
                isTicking: isTicking,
                hasCountdown: hasCountdown
            )
        }
        set {
            name = newValue.name
            intervals = newValue.intervals
            rounds = newValue.rounds
            selectedSound = newValue.sound
            isVibrating = newValue.isVibrating
            isTicking = newValue.isTicking
            hasCountdown = newValue.hasCountdown
        }
    }

    convenience init(order: Int, settings: TimerSettings) {
        self.init(
            order: order,
            name: settings.name,
            rounds: settings.rounds,
            selectedSound: settings.sound,
            isVibrating: settings.isVibrating,
            intervals: settings.intervals
        )
        self.isTicking = settings.isTicking
        self.hasCountdown = settings.hasCountdown
    }

    /// Vrátí hlavní (aktivní) timer; pokud ještě neexistuje, založí ho.
    ///
    /// Jediné místo, kde hlavní timer vzniká. Dřív ho zakládala tři různá místa
    /// a na to, že se nezaložil dvakrát, dohlížela náhoda: `AppConfig.defaultTimer`
    /// byla jedna sdílená instance `@Model`, takže druhý `insert` téhož objektu
    /// SwiftData spolkla. S hodnotovým nastavením by vznikly dva řádky `order == 0`.
    ///
    /// `context.fetch` vidí i nezapsané změny v kontextu, takže je volání
    /// idempotentní i v rámci jednoho průchodu (TimerView a ContentView se
    /// při startu potkávají v nedefinovaném pořadí).
    @discardableResult
    static func mainTimer(in context: ModelContext) -> TimerData {
        // Literál 0 místo AppConfig.mainTimerOrder – #Predicate pracuje
        // spolehlivě jen s hodnotami, které vidí přímo v těle.
        let descriptor = FetchDescriptor<TimerData>(
            predicate: #Predicate<TimerData> { $0.order == 0 }
        )
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let created = TimerData(order: AppConfig.mainTimerOrder, settings: AppConfig.defaultTimer)
        context.insert(created)
        return created
    }

    /// Shoda „je to tentýž trénink“ – porovná celé nastavení kromě názvu.
    ///
    /// Nahrazuje dřívější `Equatable`, které porovnávalo **jen intervaly**.
    /// Timer se stejnými intervaly, ale jiným zvukem, se tak tvářil jako už
    /// uložený. Pojmenovaná metoda navíc říká v místě volání, co se porovnává.
    func matchesWorkout(of other: TimerData) -> Bool {
        settings.matchesWorkout(of: other.settings)
    }
}
