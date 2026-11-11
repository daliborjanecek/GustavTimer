//
//  FavouriteTimers.swift
//  GustavTimer
//
//  Created by Dalibor Janeček on 10.11.2026.
//
//  Jediné místo pro práci s oblíbenými timery – načtení, uložení, uložení
//  změn, vrácení, odebrání a pořadí.
//
//  Model: hlavní timer (`order == 0`) je pracovní kopie. Když vznikne
//  z oblíbeného, pamatuje si ho v `sourceID`. Podle toho se pozná, jestli
//  jsou úpravy uložené:
//
//      .unsaved          – žádný zdroj (preset, odkaz, nový timer)
//      .saved(fav)       – nastavení se shoduje se zdrojem (vč. názvu)
//      .modified(fav)    – nastavení se od zdroje liší
//
//  Úpravy se do oblíbeného nepropisují samy. Uloží je až `saveChanges`,
//  takže jednorázová úprava na jeden trénink oblíbený nepřepíše.
//
//      FavouriteTimers.load(favourite, in: context)
//      // … úprava zvuku …
//      FavouriteTimers.state(in: context)   // .modified(favourite)
//      FavouriteTimers.saveChanges(in: context)
//

import Foundation
import SwiftData

enum FavouriteTimers {

    // MARK: - Stav

    /// Vztah hlavního timeru k oblíbeným.
    enum SaveState {
        case unsaved
        case saved(TimerData)
        case modified(TimerData)

        /// Oblíbený, ze kterého hlavní timer vznikl (jen když ještě existuje).
        var source: TimerData? {
            switch self {
            case .unsaved: return nil
            case .saved(let favourite), .modified(let favourite): return favourite
            }
        }

        var isModified: Bool {
            if case .modified = self { return true }
            return false
        }
    }

    /// Stav jako hodnota – čistá funkce, kterou testuje `FavouriteTimersTests`.
    enum Status: Equatable {
        case unsaved
        case saved(UUID)
        case modified(UUID)
    }

    /// Smazaný zdroj se bere jako „neuloženo“.
    static func status(
        main: TimerSettings,
        sourceID: UUID?,
        favourites: [(id: UUID, settings: TimerSettings)]
    ) -> Status {
        guard let sourceID, let source = favourites.first(where: { $0.id == sourceID }) else {
            return .unsaved
        }
        return source.settings == main ? .saved(sourceID) : .modified(sourceID)
    }

    /// Stav nad daty, která už view má z `@Query`.
    static func state(main: TimerData, favourites: [TimerData]) -> SaveState {
        let status = status(
            main: main.settings,
            sourceID: main.sourceID,
            favourites: favourites.map { ($0.id, $0.settings) }
        )
        switch status {
        case .unsaved:
            return .unsaved
        case .saved(let id):
            return favourites.first { $0.id == id }.map(SaveState.saved) ?? .unsaved
        case .modified(let id):
            return favourites.first { $0.id == id }.map(SaveState.modified) ?? .unsaved
        }
    }

    static func state(in context: ModelContext) -> SaveState {
        state(main: TimerData.mainTimer(in: context), favourites: favourites(in: context))
    }

    // MARK: - Načtení

    /// Načte oblíbený do hlavního timeru a započítá mu použití.
    static func load(_ favourite: TimerData, in context: ModelContext) {
        favourite.selected()
        let main = TimerData.mainTimer(in: context)
        main.settings = favourite.settings
        main.sourceID = favourite.id
        save(context)
    }

    /// Načte preset nebo timer z odkazu – ty v oblíbených nejsou.
    static func load(_ settings: TimerSettings, in context: ModelContext) {
        let main = TimerData.mainTimer(in: context)
        main.settings = settings
        main.sourceID = nil
        save(context)
    }

    // MARK: - Ukládání

    /// Uloží hlavní timer jako nový oblíbený a propojí ho s ním.
    ///
    /// - Parameter name: název z dialogu; prázdný nechá stávající název.
    @discardableResult
    static func saveAsNew(name: String, in context: ModelContext) -> TimerData {
        let main = TimerData.mainTimer(in: context)
        var settings = main.settings
        settings.name = resolvedName(name, fallback: main.name)

        let favourite = TimerData(order: nextOrder(in: context), settings: settings)
        context.insert(favourite)
        main.name = settings.name
        main.sourceID = favourite.id
        save(context)
        return favourite
    }

    /// Zapíše úpravy hlavního timeru do oblíbeného, ze kterého vznikl.
    static func saveChanges(in context: ModelContext) {
        guard let source = state(in: context).source else { return }
        source.settings = TimerData.mainTimer(in: context).settings
        save(context)
    }

    /// Zahodí úpravy – hlavní timer dostane zpátky uložené nastavení.
    static func revert(in context: ModelContext) {
        guard let source = state(in: context).source else { return }
        TimerData.mainTimer(in: context).settings = source.settings
        save(context)
    }

    /// Přejmenuje oblíbený. Když je zrovna načtený, přejmenuje i hlavní timer,
    /// ať zůstane uložený.
    static func rename(_ favourite: TimerData, to name: String, in context: ModelContext) {
        let main = TimerData.mainTimer(in: context)
        let resolved = resolvedName(name, fallback: favourite.name)
        if main.sourceID == favourite.id {
            main.name = resolved
        }
        favourite.name = resolved
        save(context)
    }

    /// Smaže oblíbený. Hlavní timer si nechá nastavení, jen přestane být uložený.
    static func remove(_ favourite: TimerData, in context: ModelContext) {
        let main = TimerData.mainTimer(in: context)
        if main.sourceID == favourite.id {
            main.sourceID = nil
        }
        context.delete(favourite)
        save(context)
    }

    /// Uloží nové pořadí oblíbených, jak jdou v seznamu odshora.
    ///
    /// Seznam se řadí podle `order` sestupně a `0` patří hlavnímu timeru,
    /// takže první dostane nejvyšší číslo a poslední `1`.
    static func reorder(_ favourites: [TimerData], in context: ModelContext) {
        for (index, favourite) in favourites.enumerated() {
            favourite.order = favourites.count - index
        }
        save(context)
    }

    // MARK: - Migrace

    /// Propojí hlavní timer s oblíbeným, který se s ním shoduje úplně
    /// (vč. názvu). Pro instalace z doby před `sourceID` – volá se při startu.
    static func linkLegacySource(in context: ModelContext) {
        let main = TimerData.mainTimer(in: context)
        guard main.sourceID == nil else { return }
        let favourites = favourites(in: context)
        main.sourceID = legacySourceID(
            main: main.settings,
            favourites: favourites.map { ($0.id, $0.settings) }
        )
    }

    /// Jen úplná shoda – podobný timer s jiným názvem nebo zvukem se nepropojí.
    static func legacySourceID(main: TimerSettings, favourites: [(id: UUID, settings: TimerSettings)]) -> UUID? {
        favourites.first { $0.settings == main }?.id
    }

    // MARK: - Pomocné

    /// Název z dialogu, ořezaný a omezený délkou. Vymazané pole se nebere jako
    /// „pojmenuj to prázdně“ – v oblíbených by z toho byl bezejmenný řádek.
    static func resolvedName(_ name: String, fallback: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return String((trimmed.isEmpty ? fallback : trimmed).prefix(AppConfig.maxTimerTitle))
    }

    static func favourites(in context: ModelContext) -> [TimerData] {
        let descriptor = FetchDescriptor<TimerData>(predicate: #Predicate<TimerData> { $0.order > 0 })
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Nový oblíbený jde nahoru – seznam se řadí podle `order` sestupně.
    private static func nextOrder(in context: ModelContext) -> Int {
        let all = (try? context.fetch(FetchDescriptor<TimerData>())) ?? []
        return (all.map(\.order).max() ?? 0) + 1
    }

    private static func save(_ context: ModelContext) {
        try? context.save()
    }
}
