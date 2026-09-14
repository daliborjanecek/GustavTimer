//
//  SettingsMigration.swift
//  GustavTimer
//
//  Created by Dalibor Janeček on 14.09.2026.
//
//  Jednorázový přesun nastavení timeru z UserDefaults do SwiftData.
//
//  Do verze 2.3 byl zdroj pravdy rozdělený: počet kol, vibrace a tikání se
//  četly z UserDefaults, zatímco `TimerData` drželo vlastní kopie, do kterých
//  se skoro nezapisovalo. Kopíruje se proto UserDefaults → SwiftData, ne naopak.
//
//  Zvuk je výjimka: `SoundSettingsView` psal odjakživa přímo do
//  `TimerData.selectedSound`, takže model je v tomhle jediném případě
//  aktuálnější než UserDefaults.
//

import Foundation
import SwiftData

enum SettingsMigration {

    private static let flagKey = "didMigrateTimerSettingsToSwiftData"

    /// Spustí migraci, pokud ještě neproběhla. Volá se z `ContentView.onAppear`
    /// hned po založení výchozích dat.
    static func runIfNeeded(context: ModelContext, defaults: UserDefaults = .standard) {
        guard !defaults.bool(forKey: flagKey) else { return }

        let descriptor = FetchDescriptor<TimerData>(
            predicate: #Predicate<TimerData> { $0.order == 0 }
        )

        guard let active = try? context.fetch(descriptor).first else {
            // Aktivní timer ještě neexistuje (úplně první spuštění nebo se
            // ContentView k založení dat teprve chystá). Migraci neoznačuj za
            // hotovou – proběhne při dalším startu. Čerstvá instalace nemá
            // v UserDefaults co migrovat, takže se tím nic neztrácí.
            return
        }

        if defaults.object(forKey: AppPreferences.Key.Legacy.rounds) != nil {
            active.rounds = defaults.integer(forKey: AppPreferences.Key.Legacy.rounds)
        }

        if defaults.object(forKey: AppPreferences.Key.Legacy.isVibrating) != nil {
            active.isVibrating = defaults.bool(forKey: AppPreferences.Key.Legacy.isVibrating)
        }

        // Tikání v modelu dosud neexistovalo, takže se přebírá vždy.
        active.isTicking = defaults.bool(forKey: AppPreferences.Key.Legacy.isTicking)

        // Výběr zvuku je v modelu aktuální; respektuje se jen tvrdé vypnutí.
        if defaults.object(forKey: AppPreferences.Key.Legacy.isSoundEnabled) != nil,
           defaults.bool(forKey: AppPreferences.Key.Legacy.isSoundEnabled) == false {
            active.selectedSound = nil
        }

        // Zvuk, který si uživatel naposledy vybral, ať přepínač ztlumení
        // v nastavení nabídne jeho a ne výchozí beep.
        if let sound = active.selectedSound {
            defaults.set(sound.rawValue, forKey: AppPreferences.Key.lastSelectedSound)
        }

        do {
            try context.save()
        } catch {
            // Migrace se nepovedla – nech příznak nenastavený a zkus to při
            // dalším startu. Uživatel mezitím jede na hodnotách z modelu.
            print("Chyba při migraci nastavení: \(error)")
            return
        }

        AppPreferences.Key.Legacy.all.forEach(defaults.removeObject(forKey:))
        defaults.set(true, forKey: flagKey)
    }
}
