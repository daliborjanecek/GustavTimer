//
//  SettingsViewModel.swift
//  GustavTimer
//
//  Created by Dalibor Janeček on 11.11.2026.
//
//  Logika nastavení a oblíbených. `SettingsView` a `FavouritesView` jen
//  kreslí a volají sem – úpravy timeru, ukládání do oblíbených i analytika
//  jsou tady.
//
//  Seznam oblíbených si views drží samy přes `@Query` (jen ten se umí sám
//  obnovit, když oblíbený přibude nebo zmizí) a předávají ho sem tam, kde
//  je potřeba. Aktivní timer je jeden řádek, který nikdy nezaniká, takže
//  ho ViewModel drží napořád.
//
//      SettingsView(context: context)          // založí ViewModel
//      FavouritesView(viewModel: viewModel)    // sdílí ho
//

import Foundation
import Combine
import SwiftData

final class SettingsViewModel: ObservableObject {

    /// Aktivní timer – pracovní kopie, kterou nastavení upravuje.
    let timer: TimerData

    /// Naposledy použité oblíbené pro sekci v nastavení. Pořadí se přepočítá
    /// jen při otevření a při změně počtu, ať řádky po výběru neskáčou.
    @Published private(set) var recentFavourites: [TimerData] = []

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
        self.timer = TimerData.mainTimer(in: context)
    }

    // MARK: - Název a intervaly

    /// Název timeru. Zápis se neukládá explicitně – spoléhá na autosave
    /// SwiftData, zápis na disk při každém stisku klávesy by byl zbytečný.
    var name: String {
        get { timer.name }
        set { timer.rename(to: newValue) }
    }

    func renameInterval(_ id: UUID, to name: String) {
        timer.renameInterval(id: id, to: name)
    }

    func setIntervalValue(_ id: UUID, to value: Int) {
        timer.setIntervalValue(id: id, to: value)
    }

    func addInterval() {
        guard timer.addInterval() else { return }
        Analytics.settingChanged("interval_added", value: timer.intervals.count)
    }

    func removeIntervals(at offsets: IndexSet) {
        guard timer.removeIntervals(at: offsets) else { return }
        Analytics.settingChanged("interval_removed", value: timer.intervals.count)
    }

    func moveIntervals(from source: IndexSet, to destination: Int) {
        timer.moveIntervals(from: source, to: destination)
    }

    /// Souhrn pod intervaly: délka kola, u více kol i celého tréninku,
    /// a u plného timeru upozornění na limit.
    var intervalsSummary: String {
        let settings = timer.settings
        var summary: String
        if let total = settings.totalDuration {
            summary = "SUM_ROUND_AND_TIMER_DESCRIPTION".localized(with: settings.roundDuration.asTime(), total.asTime())
        } else {
            summary = "SUM_ROUND_DESCRIPTION".localized(with: settings.roundDuration.asTime())
        }
        if !timer.canAddInterval {
            summary += " " + "MAX_LIMIT_REACHED".localized(with: AppConfig.maxTimerCount)
        }
        return summary
    }

    // MARK: - Volby timeru

    /// Zapíše jednu volbu aktivního timeru a hned uloží, ať se neztratí,
    /// když uživatel zavře nastavení swipem.
    ///
    ///     viewModel.update(\.isVibrating, to: false, tracking: "haptics")
    ///
    /// - Parameter name: název volby pro `settings.changed`; `nil` = neposílat
    ///   (zvuk má vlastní signál v `SoundSettingsView`).
    func update<Value>(
        _ keyPath: ReferenceWritableKeyPath<TimerData, Value>,
        to value: Value,
        tracking name: String? = nil
    ) {
        timer[keyPath: keyPath] = value
        try? context.save()
        if let name {
            Analytics.settingChanged(name, value: value)
        }
    }

    // MARK: - Stav uložení

    /// Je aktivní timer uložený v oblíbených, a jsou uložené i jeho úpravy?
    func saveState(among favourites: [TimerData]) -> FavouriteTimers.SaveState {
        FavouriteTimers.state(main: timer, favourites: favourites)
    }

    /// Oblíbený je vybraný, když z něj aktivní timer vznikl – i když je upravený.
    func isSelected(_ favourite: TimerData) -> Bool {
        timer.sourceID == favourite.id
    }

    /// Preset v databázi není, takže se pozná jen shodou tréninku – a jen
    /// když aktivní timer nepochází z oblíbeného.
    func isSelected(_ preset: PredefinedTimer) -> Bool {
        timer.sourceID == nil && timer.settings.matchesWorkout(of: preset.settings)
    }

    // MARK: - Oblíbené

    func refreshRecentFavourites(from favourites: [TimerData]) {
        recentFavourites = favourites.sorted {
            ($0.lastUsed ?? .distantPast) > ($1.lastUsed ?? .distantPast)
        }
    }

    /// Je oblíbený načtený a upravený? Výběr by pak úpravy tiše zahodil,
    /// takže se view nejdřív zeptá, jestli je uložit, nebo vrátit uložené.
    func needsDecision(on favourite: TimerData, among favourites: [TimerData]) -> Bool {
        isSelected(favourite) && saveState(among: favourites).isModified
    }

    func select(_ favourite: TimerData, screen: TimerSelectionScreen) {
        FavouriteTimers.load(favourite, in: context)
        Analytics.favouriteSelected(favourite, screen: screen)
    }

    func select(_ preset: PredefinedTimer, screen: TimerSelectionScreen) {
        Analytics.presetSelected(preset, screen: screen)
        FavouriteTimers.load(preset.settings, in: context)
    }

    /// Uloží aktivní timer jako nový oblíbený.
    ///
    /// - Parameter name: název z dialogu; prázdný nechá stávající název.
    func saveAsNew(name: String, screen: TimerSelectionScreen) {
        let favourite = FavouriteTimers.saveAsNew(name: name, in: context)
        Analytics.timerSaved(favourite.settings, screen: screen, mode: .new)
    }

    /// Zapíše úpravy do oblíbeného, ze kterého aktivní timer vznikl.
    func saveChanges(screen: TimerSelectionScreen = .settings) {
        FavouriteTimers.saveChanges(in: context)
        Analytics.timerSaved(timer.settings, screen: screen, mode: .update)
    }

    /// Zahodí úpravy a vrátí uložené nastavení.
    func revertChanges() {
        FavouriteTimers.revert(in: context)
        Analytics.send(.timerReverted)
    }

    func rename(_ favourite: TimerData, to name: String) {
        FavouriteTimers.rename(favourite, to: name, in: context)
        Analytics.settingChanged("favourite", value: "renamed")
    }

    func remove(_ favourite: TimerData) {
        FavouriteTimers.remove(favourite, in: context)
        Analytics.settingChanged("favourite", value: "removed")
    }

    /// Přesune oblíbené v seznamu a uloží nové pořadí.
    func moveFavourites(_ favourites: [TimerData], from source: IndexSet, to destination: Int) {
        var reordered = favourites
        reordered.move(fromOffsets: source, toOffset: destination)
        FavouriteTimers.reorder(reordered, in: context)
    }

    // MARK: - Odkazy

    /// Otevře odkaz ze sekce „Více“, který přišel z API.
    @MainActor
    func open(_ link: RemoteLink) {
        Analytics.send(.externalLinkOpened, parameters: ["target": "remote_link", "link_id": link.id])
        AppLinkRouter.open(link.url)
    }
}
