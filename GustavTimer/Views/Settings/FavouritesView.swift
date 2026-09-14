//
//  FavouritesView.swift
//  GustavTimer
//
//  Created by Dalibor Janeček on 10.11.2025.
//

import SwiftUI
import SwiftData
import GustavUICore
import TelemetryDeck

struct FavouritesView: View {
    
    @Query(sort: \TimerData.order, order: .reverse) var timerData: [TimerData]
    @Environment(\.modelContext) var context
    
    @State var showSaveAlert: Bool = false
    @State var newTimerName: String = ""
    @State var showDeleteAlert: Bool = false
    @State var timerToDelete: TimerData?
    @State var showAlreadySavedAlert: Bool = false
    @State private var editMode: EditMode = .inactive
    @State private var selectedTip: Int = Int.random(in: 0...2)
    
    var body: some View {
        List {
            savedTimers
            preloadedTimers
        }
        .navigationBarTitleDisplayMode(.automatic)
        .toolbar { toolbar }
        .environment(\.editMode, $editMode)
        .saveTimerAlert(isPresented: $showSaveAlert, timerName: $newTimerName, onSave: saveTimer)
        .alreadySavedAlert(isPresented: $showAlreadySavedAlert)
    }
    
    @ViewBuilder
    private var savedTimers: some View {
        Section {
            let savedTimers = timerData.filter { $0.order != 0 }
            if !savedTimers.isEmpty {
                ForEach(savedTimers) { timer in
                    FavouriteRowView(timer: timer, selected: isTimerSelected(timer: timer))
                        .onTapGesture {
                            selectTimer(timer: timer)
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            if let url = deeplinkURL(for: timer) {
                                ShareLink(item: url) {
                                    Label("SHARE", systemImage: "square.and.arrow.up")
                                }
                                .tint(Color.gustavVolt)
                            }
                        }
                }
                .onDelete { indexSet in
                    if let index = indexSet.first {
                        timerToDelete = savedTimers[index]
                        deleteTimer()
                    }
                }
                .onMove(perform: moveTimer)
            } else {
                FavouritesEmptyView()
            }
        } header: {
            Text("SAVED_TIMERS").font(.sectionHeader)
        }
        .animation(.spring, value: editMode)
    }
    
    @ViewBuilder
    private var preloadedTimers: some View {
        Section {
            let preloadedTimers = PredefinedTimer.allCases
            ForEach(preloadedTimers) { timer in
                FavouriteRowView(timer: timer.timer, selected: isTimerSelected(timer: timer.timer), tip: timer.description[selectedTip])
                    .onTapGesture {
                        analyticsPreloadedAction(timer: timer.timer)
                        selectTimer(timer: timer.timer)
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        if let url = deeplinkURL(for: timer.timer) {
                            ShareLink(item: url) {
                                Label("SHARE", systemImage: "square.and.arrow.up")
                            }
                            .tint(Color.gustavVolt)
                        }
                    }
            }
        } header: {
            Text("PRELOADED_TIMERS").font(.sectionHeader)
        }
        .animation(.spring, value: editMode)
    }
    
    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        if #available(iOS 26, *){
            ToolbarItem(placement: .title) {
                HStack {
                    Text("FAVOURITES")
                        .font(.settingsNavbarTitle)
                }
                .padding(.vertical)
            }
        } else {
            // Fallback to earlier versions
            ToolbarItem(placement: .title) {
                HStack {
                    Text("FAVOURITES")
                        .font(.settingsNavbarTitle)
                }
                .padding(.vertical)
            }
        }
        
        ToolbarItem {
            Button {
                let savedTimers = timerData.filter { $0.order != 0 }
                if let mainTimer = timerData.first(where: { $0.order == 0 }),
                   !savedTimers.contains(where: { $0.matchesWorkout(of: mainTimer) }) {
                    showSaveAlert.toggle()
                } else {
                    showAlreadySavedAlert.toggle()
                }
            } label: {
                Image(systemName: "plus")
            }
        }
        
        ToolbarItem {
            if timerData.count > 2 {
                Button {
                    editMode = (editMode == .active ? .inactive : .active)
                } label: {
                    Image(systemName: "slider.horizontal.3")
                }
            }
        }
    }
    
    private func moveTimer(from indices: IndexSet, to newOffset: Int) {
        // Získáme pouze uložené časovače (bez hlavního časovače)
        let savedTimers = timerData.filter { $0.order != 0 }
        
        // Vytvoříme kopii časovačů, se kterou můžeme pracovat
        var movedTimers = savedTimers
        
        // Provedeme přesun v naší kopii
        movedTimers.move(fromOffsets: indices, toOffset: newOffset)
        
        // Přiřadíme nová ID pro zachování pořadí
        // Začínáme od 1, protože 0 je rezervováno pro hlavní časovač
        for i in 0..<movedTimers.count {
            let timer = movedTimers[i]
            // Nastavíme nové ID, které určuje pořadí (vyšší ID = novější časovač)
            timer.order = movedTimers.count - i
        }
        
        // Uložíme změny do databáze
        try? context.save()
    }
    
    private func deleteTimer() {
        if let timerToDelete = timerToDelete {
            context.delete(timerToDelete)
        }
    }
    
    private func saveTimer() {
        if let mainTimer = timerData.first(where: { $0.order == 0 }) {
            let newId = (timerData.map { $0.order }.max() ?? 0) + 1
            var settings = mainTimer.settings
            settings.name = newTimerName
            let newTimer = TimerData(order: newId, settings: settings)
            context.insert(newTimer)
            // Aktivní timer převezme pojmenování, aby se hned poznal jako uložený.
            mainTimer.name = newTimerName

            // Track timer save event
            let intervalPattern = newTimer.intervals.map { String($0.value) }.joined(separator: "/")
            TelemetryDeck.signal(
                "timer.saved",
                parameters: [
                    "interval_pattern": intervalPattern
                ]
            )
        }
    }
    
    private func selectTimer(timer: TimerData) {
        timer.selected()
        if let mainTimer = timerData.first(where: { $0.order == 0 }) {
            mainTimer.settings = timer.settings
            try? context.save()
        }
    }
    
    private func analyticsPreloadedAction(timer: TimerData) {
        let intervalPattern = timer.intervals.map { String($0.value) }.joined(separator: "/")

        TelemetryDeck.signal(
            "timer.preloadselected",
            parameters: [
                "timer_name": timer.name,
                "interval_pattern": intervalPattern
            ]
        )
    }
    
    private func isTimerSelected(timer: TimerData) -> Bool {
        if let mainTimer = timerData.first(where: { $0.order == 0 }) {
            return mainTimer.matchesWorkout(of: timer)
        }
        return false
    }

    /// Sdílený odkaz na timer ve tvaru `https://gustavtraining.com/t?...`.
    /// Skládání drží `SharedTimerLink`, aby generování a parsování nemohlo
    /// vzniknout ve dvou nezávislých kopiích.
    private func deeplinkURL(for timer: TimerData) -> URL? {
        SharedTimerLink.url(
            settings: timer.settings,
            limits: SharedTimerLink.Limits(
                maxIntervalCount: AppConfig.maxTimerCount,
                maxIntervalValue: AppConfig.maxTimerValue,
                maxRounds: AppConfig.roundsOptions.last ?? 31
            )
        )
    }
}

#Preview {
    List {
        FavouritesEmptyView()
        FavouriteRowView(timer: {
            let timer = TimerData(order: 11, settings: AppConfig.defaultTimer)
            timer.intervals = [
                IntervalData(value: 30, name: "Work"),
                IntervalData(value: 15, name: "Rest")
            ]
            return timer
        }(), selected: false)
    }
}
