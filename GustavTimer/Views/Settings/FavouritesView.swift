//
//  FavouritesView.swift
//  GustavTimer
//
//  Created by Dalibor Janeček on 10.11.2025.
//

import SwiftUI
import SwiftData
import GustavUICore

/// Seznam oblíbených a přednastavených timerů. Výběr, ukládání a pořadí
/// dělá `SettingsViewModel`, který sdílí se `SettingsView`.
///
///     NavigationLink {
///         FavouritesView(viewModel: viewModel)
///     } label: { … }
struct FavouritesView: View {

    @ObservedObject var viewModel: SettingsViewModel
    @Query(sort: \TimerData.order, order: .reverse) private var timerData: [TimerData]

    @State private var showSaveAlert = false
    @State private var newTimerName = ""
    /// Upravený oblíbený, na který uživatel ťukl – čeká na rozhodnutí.
    @State private var modifiedFavourite: TimerData?
    @State private var editMode: EditMode = .inactive
    /// Který ze tří tipů u presetů se ukáže – vybraný jednou za zobrazení.
    @State private var selectedTip = Int.random(in: 0...2)

    /// Uložené oblíbené (bez hlavního timeru), odshora podle pořadí.
    private var favouriteTimers: [TimerData] {
        timerData.filter { $0.order > AppConfig.mainTimerOrder }
    }

    var body: some View {
        List {
            savedTimers
            preloadedTimers
        }
        .navigationBarTitleDisplayMode(.automatic)
        .settingsTitle("FAVOURITES")
        .toolbar { toolbar }
        .environment(\.editMode, $editMode)
        .saveTimerAlert(isPresented: $showSaveAlert, timerName: $newTimerName) {
            viewModel.saveAsNew(name: newTimerName, screen: .favourites)
        }
        .modifiedFavouriteDialog(
            favourite: $modifiedFavourite,
            onSave: { _ in viewModel.saveChanges(screen: .favourites) },
            onRevert: { withAnimation { viewModel.revertChanges() } }
        )
    }

    private var savedTimers: some View {
        Section {
            let favourites = favouriteTimers
            if favourites.isEmpty {
                FavouritesEmptyView()
            } else {
                let isModified = viewModel.saveState(among: favourites).isModified
                ForEach(favourites) { favourite in
                    let selected = viewModel.isSelected(favourite)
                    FavouriteRowView(
                        settings: favourite.settings,
                        selected: selected,
                        isModified: selected && isModified
                    )
                    .onTapGesture {
                        if viewModel.needsDecision(on: favourite, among: favourites) {
                            modifiedFavourite = favourite
                        } else {
                            viewModel.select(favourite, screen: .favourites)
                        }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        shareButton(for: favourite.settings, origin: .favourite)
                    }
                }
                .onDelete { offsets in
                    offsets.map { favourites[$0] }.forEach(viewModel.remove)
                }
                .onMove { source, destination in
                    viewModel.moveFavourites(favourites, from: source, to: destination)
                }
            }
        } header: {
            Text("SAVED_TIMERS").font(.sectionHeader)
        }
        .animation(.spring, value: editMode)
    }

    private var preloadedTimers: some View {
        Section {
            ForEach(PredefinedTimer.allCases) { preset in
                FavouriteRowView(
                    settings: preset.settings,
                    selected: viewModel.isSelected(preset),
                    tip: preset.description[selectedTip]
                )
                .onTapGesture {
                    viewModel.select(preset, screen: .favourites)
                }
                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                    shareButton(for: preset.settings, origin: .preset)
                }
            }
        } header: {
            Text("PRELOADED_TIMERS").font(.sectionHeader)
        }
        .animation(.spring, value: editMode)
    }

    /// Sdílení odkazu na timer ze swipu. Timer, který se do odkazu nevejde,
    /// tlačítko nedostane.
    @ViewBuilder
    private func shareButton(for settings: TimerSettings, origin: TimerShareOrigin) -> some View {
        if TimerShareSheet.url(for: settings) != nil {
            Button {
                TimerShareSheet.present(settings: settings, origin: origin)
            } label: {
                Label("SHARE", systemImage: "square.and.arrow.up")
            }
            .tint(Color.gustavVolt)
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem {
            // Vždy uloží aktivní timer jako nový oblíbený. Dialog startuje se
            // stávajícím názvem, ať ho uživatel nemusí psát znovu.
            Button {
                newTimerName = viewModel.timer.name
                showSaveAlert = true
            } label: {
                Image(systemName: "plus")
            }
        }

        ToolbarItem {
            // Řazení má smysl až od dvou oblíbených.
            if favouriteTimers.count > 1 {
                Button {
                    editMode = (editMode == .active ? .inactive : .active)
                } label: {
                    Image(systemName: "slider.horizontal.3")
                }
            }
        }
    }
}

#Preview("S oblíbenými") {
    NavigationStack {
        FavouritesView(viewModel: SettingsViewModel(context: PreviewData.container.mainContext))
    }
    .modelContainer(PreviewData.container)
}

#Preview("Prázdné") {
    NavigationStack {
        FavouritesView(viewModel: SettingsViewModel(context: PreviewData.emptyContainer.mainContext))
    }
    .modelContainer(PreviewData.emptyContainer)
}
