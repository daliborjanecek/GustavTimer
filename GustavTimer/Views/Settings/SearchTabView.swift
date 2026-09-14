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
                let favouriteResults = searchResults()
                let predefinedResults = searchResults(searchPredefined: true)
                
                if !favouriteResults.isEmpty {
                    Section {
                        ForEach(favouriteResults) { timer in
                            FavouriteRowView(timer: timer, selected: isTimerSelected(timer: timer))
                                .onTapGesture {
                                    selectTimer(timer: timer)
                                }
                        }
                    } header: {
                        if searchResults(searchPredefined: true).isEmpty == false {
                            Text("FAVOURITES")
                        }
                    }
                }
                
                if !predefinedResults.isEmpty {
                    Section {
                        ForEach(predefinedResults) { timer in
                            FavouriteRowView(timer: timer, selected: isTimerSelected(timer: timer))
                                .onTapGesture {
                                    selectTimer(timer: timer)
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
    
    private func isTimerSelected(timer: TimerData) -> Bool {
        if let mainTimer = timerData.first(where: { $0.order == 0 }) {
            return mainTimer.matchesWorkout(of: timer)
        }
        return false
    }
    
    private func searchResults(searchPredefined: Bool = false) -> [TimerData] {
        var searchedTimers: [TimerData] = []
        if searchPredefined {
            searchedTimers = AppConfig.predefinedTimers
        } else {
            searchedTimers = timerData.filter { $0.order != 0 }
        }
        if searchText.isEmpty {
            return searchedTimers
        } else {
            return searchedTimers.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    private func selectTimer(timer: TimerData) {
        timer.selected()
        if let mainTimer = timerData.first(where: { $0.order == 0 }) {
            mainTimer.settings = timer.settings
            try? context.save()
        }
    }
}
