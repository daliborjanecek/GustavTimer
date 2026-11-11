//
//  FavouritesView.swift
//  GustavTimer
//
//  Created by Dalibor Janeček on 10.11.2025.
//

import SwiftUI
import SwiftData
import GustavUICore

struct FavouritesView: View {
    
    @Query(sort: \TimerData.order, order: .reverse) var timerData: [TimerData]
    @Environment(\.modelContext) var context
    
    @State var showSaveAlert: Bool = false
    @State var newTimerName: String = ""
    @State var timerToDelete: TimerData?
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
    }
    
    @ViewBuilder
    private var savedTimers: some View {
        Section {
            let savedTimers = favouriteTimers
            if !savedTimers.isEmpty {
                ForEach(savedTimers) { timer in
                    let selected = isSelected(timer)
                    FavouriteRowView(
                        settings: timer.settings,
                        selected: selected,
                        isModified: selected && isMainTimerModified
                    )
                        .onTapGesture {
                            select(timer)
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            if TimerShareSheet.url(for: timer.settings) != nil {
                                Button {
                                    TimerShareSheet.present(settings: timer.settings, origin: .favourite)
                                } label: {
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
            ForEach(preloadedTimers) { preset in
                FavouriteRowView(settings: preset.settings, selected: isSelected(preset), tip: preset.description[selectedTip])
                    .onTapGesture {
                        Analytics.presetSelected(preset, screen: .favourites)
                        FavouriteTimers.load(preset.settings, in: context)
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        if TimerShareSheet.url(for: preset.settings) != nil {
                            Button {
                                TimerShareSheet.present(settings: preset.settings, origin: .preset)
                            } label: {
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
            // Vždy uloží aktivní timer jako nový oblíbený. Dialog startuje se
            // stávajícím názvem, ať ho uživatel nemusí psát znovu.
            Button {
                newTimerName = TimerData.mainTimer(in: context).name
                showSaveAlert = true
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
        let savedTimers = favouriteTimers
        
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
            FavouriteTimers.remove(timerToDelete, in: context)
        }
    }
    
    private func saveTimer() {
        let favourite = FavouriteTimers.saveAsNew(name: newTimerName, in: context)
        Analytics.timerSaved(favourite.settings, screen: .favourites, mode: .new)
    }

    private func select(_ timer: TimerData) {
        FavouriteTimers.load(timer, in: context)
        Analytics.favouriteSelected(timer, screen: .favourites)
    }

    private var mainTimer: TimerData? {
        timerData.first { $0.order == AppConfig.mainTimerOrder }
    }

    private var favouriteTimers: [TimerData] {
        timerData.filter { $0.order > AppConfig.mainTimerOrder }
    }

    /// Načtený oblíbený má neuložené úpravy.
    private var isMainTimerModified: Bool {
        guard let mainTimer else { return false }
        return FavouriteTimers.state(main: mainTimer, favourites: favouriteTimers).isModified
    }

    /// Oblíbený je vybraný, když z něj aktivní timer vznikl – i když je upravený.
    private func isSelected(_ timer: TimerData) -> Bool {
        mainTimer?.sourceID == timer.id
    }

    /// Preset v databázi není, takže se pozná jen shodou tréninku – a jen
    /// když aktivní timer nepochází z oblíbeného.
    private func isSelected(_ preset: PredefinedTimer) -> Bool {
        guard let mainTimer, mainTimer.sourceID == nil else { return false }
        return mainTimer.settings.matchesWorkout(of: preset.settings)
    }
}

#Preview {
    List {
        FavouritesEmptyView()
        FavouriteRowView(settings: AppConfig.defaultTimer, selected: false)
    }
}
