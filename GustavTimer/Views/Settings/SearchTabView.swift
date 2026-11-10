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
                            FavouriteRowView(settings: timer.settings, selected: isSelected(timer))
                                .onTapGesture {
                                    FavouriteTimers.load(timer, in: context)
                                    Analytics.favouriteSelected(timer, screen: .search)
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
                            FavouriteRowView(settings: preset.settings, selected: isSelected(preset))
                                .onTapGesture {
                                    Analytics.presetSelected(preset, screen: .search)
                                    FavouriteTimers.load(preset.settings, in: context)
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
    
    private var mainTimer: TimerData? {
        timerData.first { $0.order == AppConfig.mainTimerOrder }
    }

    /// Oblíbený je vybraný, když z něj aktivní timer vznikl.
    private func isSelected(_ timer: TimerData) -> Bool {
        mainTimer?.sourceID == timer.id
    }

    /// Preset se pozná shodou tréninku – jen když timer nepochází z oblíbeného.
    private func isSelected(_ preset: PredefinedTimer) -> Bool {
        guard let mainTimer, mainTimer.sourceID == nil else { return false }
        return mainTimer.settings.matchesWorkout(of: preset.settings)
    }

    /// Uložené oblíbené odpovídající hledání. Vrací `TimerData`, protože
    /// výběr jim započítává použití.
    private func favouriteResults() -> [TimerData] {
        let saved = timerData.filter { $0.order > AppConfig.mainTimerOrder }
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
}
