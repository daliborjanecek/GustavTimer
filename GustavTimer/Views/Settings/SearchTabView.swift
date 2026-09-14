//
//  SearchTabView.swift
//  GustavTimer
//
//  Created by Dalibor Janeček on 19.09.2025.
//

import SwiftUI
import SwiftData

struct SearchTabView: View {
    @Binding var searchText: String
    @FocusState private var isFocused: Bool
    @Query(sort: \TimerData.order, order: .reverse) var timerData: [TimerData]
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var context
    
    var body: some View {
        NavigationStack {
            List {
                let favouriteResults = favouriteResults()
                let predefinedResults = predefinedResults()

                if !favouriteResults.isEmpty {
                    Section {
                        ForEach(favouriteResults) { timer in
                            FavouriteRowView(settings: timer.settings, selected: isSelected(timer.settings))
                                .onTapGesture {
                                    select(timer.settings, tracking: timer)
                                }
                        }
                    } header: {
                        if !predefinedResults.isEmpty {
                            Text("FAVOURITES")
                        }
                    }
                }

                if !predefinedResults.isEmpty {
                    Section {
                        ForEach(predefinedResults) { preset in
                            FavouriteRowView(settings: preset.settings, selected: isSelected(preset.settings))
                                .onTapGesture {
                                    select(preset.settings)
                                }
                        }
                    } header: {
                        Text("PRELOADED_TIMERS")
                    }
                }
                
                Spacer(minLength: 300)
                    .listRowBackground(Color.clear)
            }
            .navigationBarTitleDisplayMode(.automatic)
        }
    }
    
    private func isSelected(_ settings: TimerSettings) -> Bool {
        guard let mainTimer = timerData.first(where: { $0.order == AppConfig.mainTimerOrder }) else { return false }
        return mainTimer.settings.matchesWorkout(of: settings)
    }

    /// Uložené oblíbené odpovídající hledání. Vrací `TimerData`, protože
    /// výběr jim započítává použití.
    private func favouriteResults() -> [TimerData] {
        let saved = timerData.filter { $0.order != AppConfig.mainTimerOrder }
        guard !searchText.isEmpty else { return saved }
        return saved.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    /// Presety odpovídající hledání. Ty v databázi nejsou, takže hodnoty.
    private func predefinedResults() -> [PredefinedTimer] {
        guard !searchText.isEmpty else { return PredefinedTimer.allCases }
        return PredefinedTimer.allCases.filter {
            $0.settings.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    /// Nastaví hlavní timer podle zadaného nastavení.
    ///
    /// - Parameter tracking: uložený oblíbený, kterému se má započítat použití.
    ///   Presety ho nemají – nejsou v databázi, takže není kam počítat.
    private func select(_ settings: TimerSettings, tracking timer: TimerData? = nil) {
        timer?.selected()
        TimerData.mainTimer(in: context).settings = settings
        try? context.save()
    }
}
