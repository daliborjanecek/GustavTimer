//
//  TimerData+Editing.swift
//  GustavTimer
//
//  Created by Dalibor Janeček on 11.11.2026.
//
//  Úpravy timeru v nastavení – název a intervaly – včetně limitů z `AppConfig`.
//  Dřív je dělal `SettingsView` sám. Tady jdou testovat bez view
//  (`TimerEditingTests`) a limity platí, ať úpravu volá kdokoli.
//
//      timer.rename(to: "Ranní Tabata")
//      timer.addInterval()
//      timer.setIntervalValue(id: interval.id, to: 45)
//

import Foundation
import SwiftUI

extension TimerData {

    // MARK: - Název

    /// Název se ořezává na `AppConfig.maxTimerTitle`, aby přežil průchod
    /// sdíleným odkazem bez tichého zkrácení.
    func rename(to name: String) {
        self.name = String(name.prefix(AppConfig.maxTimerTitle))
    }

    // MARK: - Intervaly

    var canAddInterval: Bool {
        intervals.count < AppConfig.maxTimerCount
    }

    /// Timer musí mít aspoň jeden interval.
    var canRemoveInterval: Bool {
        intervals.count > 1
    }

    /// Přidá na konec nový interval s výchozí délkou.
    ///
    /// - Returns: `false`, když je timer plný a interval nepřibyl.
    @discardableResult
    func addInterval() -> Bool {
        guard canAddInterval else { return false }
        let name = "ROUND".localized + " \(intervals.count + 1)"
        intervals.append(IntervalData(value: AppConfig.newIntervalValue, name: name))
        return true
    }

    /// Smaže intervaly. Poslední interval smazat nejde.
    ///
    /// - Returns: `false`, když by timer zůstal prázdný a nic se nesmazalo.
    @discardableResult
    func removeIntervals(at offsets: IndexSet) -> Bool {
        guard intervals.count - offsets.count >= 1 else { return false }
        intervals.remove(atOffsets: offsets)
        return true
    }

    func moveIntervals(from source: IndexSet, to destination: Int) {
        intervals.move(fromOffsets: source, toOffset: destination)
    }

    /// Název intervalu se ořezává na `AppConfig.maxTimerName`.
    func renameInterval(id: UUID, to name: String) {
        guard let index = intervals.firstIndex(where: { $0.id == id }) else { return }
        intervals[index].name = String(name.prefix(AppConfig.maxTimerName))
    }

    /// Délka intervalu v sekundách, držená v rozsahu 1…`AppConfig.maxTimerValue`.
    func setIntervalValue(id: UUID, to value: Int) {
        guard let index = intervals.firstIndex(where: { $0.id == id }) else { return }
        intervals[index].value = min(max(value, 1), AppConfig.maxTimerValue)
    }
}
