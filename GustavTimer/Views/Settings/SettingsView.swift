//
//  SettingsSheet.swift
//  GustavTimer
//
//  Created by Dalibor Janeček on 10.11.2025.
//

import SwiftUI
import SwiftData
import GustavUICore

/// Nastavení aktivního timeru. View jen kreslí – úpravy, ukládání do
/// oblíbených a analytiku dělá `SettingsViewModel`.
///
///     .sheet(item: $activeSheet) { _ in
///         SettingsView(context: context)
///     }
struct SettingsView: View {
    @StateObject private var viewModel: SettingsViewModel
    @Query private var timerData: [TimerData]
    @Environment(\.dismiss) private var dismiss

    @State private var editMode: EditMode = .inactive
    @State private var newTimerName = ""
    @State private var showSaveAlert = false
    @State private var renamedTimerName = ""
    @State private var showRenameAlert = false
    @ObservedObject private var remoteContent = RemoteContentManager.shared
    @ObservedObject private var navigator = AppNavigator.shared
    /// Obrazovky otevřené odkazem (`AppNavigator`) nebo z menu nastavení.
    @State private var path: [AppScreen] = []
    #if DEBUG
    @State private var showDebugMenu = false
    #endif

    init(context: ModelContext) {
        _viewModel = StateObject(wrappedValue: SettingsViewModel(context: context))
    }

    private var timer: TimerData {
        viewModel.timer
    }

    /// Uložené oblíbené (bez hlavního timeru).
    private var favouriteTimers: [TimerData] {
        timerData.filter { $0.order > AppConfig.mainTimerOrder }
    }

    private var saveState: FavouriteTimers.SaveState {
        viewModel.saveState(among: favouriteTimers)
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                SettingsBannerView()
                timerNameView
                intervalsView
                roundsView
                favourites
                feedback
                appearance
                more
                #if DEBUG
                debugEntry
                #endif
            }
            .listSectionSpacing(24)
            .scrollDismissesKeyboard(.immediately)
            .background(DismissKeyboardOnTap())
            .environment(\.editMode, $editMode)
            .saveTimerAlert(isPresented: $showSaveAlert, timerName: $newTimerName) {
                viewModel.saveAsNew(name: newTimerName, screen: .settings)
            }
            .renameTimerAlert(isPresented: $showRenameAlert, timerName: $renamedTimerName) {
                guard let favourite = saveState.source else { return }
                viewModel.rename(favourite, to: renamedTimerName)
            }
            .toolbar { toolbar }
            .font(.gustavBody)
            .onAppear {
                viewModel.refreshRecentFavourites(from: favouriteTimers)
                openPendingScreen()
            }
            // Přibyl nebo zmizel oblíbený – výběr pořadí nemění, ten se
            // schválně přepočítá až při dalším otevření.
            .onChange(of: favouriteTimers.count) { _, _ in
                viewModel.refreshRecentFavourites(from: favouriteTimers)
            }
            // Odkaz na obrazovku, když je nastavení už otevřené (banner nahoře).
            .onChange(of: navigator.pendingScreen) { _, _ in
                openPendingScreen()
            }
            .navigationDestination(for: AppScreen.self) { screen in
                switch screen {
                case .background:
                    BackgroundSelectorView()
                }
            }
            #if DEBUG
            .navigationDestination(isPresented: $showDebugMenu) {
                RemoteContentDebugView()
            }
            #endif
        }
        .tint(Color.gustavNavigationItemsColor)
    }
}

// MARK: - Sekce

private extension SettingsView {

    var timerNameView: some View {
        SettingsSection(label: "TIMER_NAME", footer: saveStateDescription) {
            TextField("TIMER_NAME_PROMPT", text: $viewModel.name)
                .font(.settingsIntervalName)
                .submitLabel(.done)
        }
    }

    /// Popis stavu uložení pod názvem timeru.
    var saveStateDescription: LocalizedStringKey {
        switch saveState {
        case .unsaved: return "STATE_UNSAVED"
        case .saved: return "STATE_SAVED"
        case .modified: return "STATE_MODIFIED"
        }
    }

    var intervalsView: some View {
        Section {
            ForEach(timer.intervals) { interval in
                IntervalRowView(
                    intervalName: Binding(
                        get: { interval.name },
                        set: { viewModel.renameInterval(interval.id, to: $0) }
                    ),
                    intervalValue: Binding(
                        get: { interval.value },
                        set: { viewModel.setIntervalValue(interval.id, to: $0) }
                    )
                )
            }
            .onDelete(perform: timer.canRemoveInterval ? { offsets in
                withAnimation(.easeInOut) { viewModel.removeIntervals(at: offsets) }
            } : nil)
            .onMove { source, destination in
                withAnimation(.easeInOut) { viewModel.moveIntervals(from: source, to: destination) }
            }
        } header: {
            Text("INTERVALS_TAB")
                .font(.sectionHeader)
                .foregroundStyle(Color.gustavNeutral)
        } footer: {
            HStack(alignment: .top, spacing: 16) {
                Text(viewModel.intervalsSummary)
                    .font(.sectionFooter)
                    .foregroundStyle(Color.gustavNeutral)
                    .multilineTextAlignment(.leading)
                Spacer()
                if timer.canAddInterval {
                    GustavSmallPillButton(label: "ADD_INTERVAL", action: addInterval)
                        .padding(.leading, -16)
                }
            }
        }
    }

    var roundsView: some View {
        Section {
            NavigationLink {
                RoundsSettingsView(rounds: setting(\.rounds, tracking: "rounds"))
            } label: {
                ListButton(name: "ROUNDS", value: "\(timer.rounds == -1 ? "LOOP".localized : String(timer.rounds))")
            }
        }
    }

    var favourites: some View {
        SettingsSection(label: "FAVOURITES") {
            ForEach(viewModel.recentFavourites.prefix(3)) { favourite in
                let isSelected = viewModel.isSelected(favourite)
                FavouriteRowView(
                    settings: favourite.settings,
                    selected: isSelected,
                    isModified: isSelected && saveState.isModified,
                    isMinimized: true
                )
                .onTapGesture {
                    DispatchQueue.main.async {
                        withAnimation {
                            viewModel.select(favourite, screen: .settings)
                        }
                    }
                }
            }
            NavigationLink {
                FavouritesView(viewModel: viewModel)
            } label: {
                Text("ALL_FAVOURITES")
            }
        }
    }

    var feedback: some View {
        SettingsSection(label: "FEEDBACK", footer: "FEEDBACK_DESCRIPTION") {
            Toggle("HAPTICS", isOn: setting(\.isVibrating, tracking: "haptics"))
                .tint(Color.gustavVolt)

            Toggle("SET_COUNTDOWN", isOn: setting(\.hasCountdown, tracking: "countdown"))
                .tint(Color.gustavVolt)

            NavigationLink {
                TickingSettingsView(ticking: setting(\.ticking, tracking: "ticking"))
            } label: {
                ListButton(name: "SET_TICKING", value: timer.ticking.title)
            }

            NavigationLink {
                SoundSettingsView(selectedSound: setting(\.selectedSound))
            } label: {
                ListButton(name: "SOUND", value: timer.selectedSound?.title ?? "MUTE")
            }
        }
    }

    var appearance: some View {
        SettingsSection(label: "APPEARANCE") {
            NavigationLink(value: AppScreen.background) {
                ListButton(name: "BACKGROUND")
            }
        }
    }

    /// Odkazy z API (včetně nástěnky nápadů). Když žádný platný odkaz z API
    /// není, ukáže se vestavěné „Ohodnoť“.
    var more: some View {
        SettingsSection(label: "MORE") {
            let remoteLinks = remoteContent.links

            ForEach(remoteLinks) { link in
                Button(link.label) {
                    viewModel.open(link)
                }
                .foregroundStyle(Color.gustavPink)
            }

            if remoteLinks.isEmpty {
                ButtonLink(label: "RATE", URLString: AppConfig.reviewURL, target: "rate")
            }
        }
    }

    #if DEBUG
    /// Číslo verze. Klepnutí otevře vývojářské menu – jen v DEBUG.
    var debugEntry: some View {
        Section {
            Text(verbatim: appVersionText)
                .font(.sectionFooter)
                .foregroundStyle(Color.gustavNeutral)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    showDebugMenu = true
                }
                .listRowBackground(Color.clear)
        }
    }

    var appVersionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }
    #endif
}

// MARK: - Toolbar

private extension SettingsView {

    @ToolbarContentBuilder
    var toolbar: some ToolbarContent {

        ToolbarItem(placement: .navigationBarLeading) {
            if #available(iOS 26.0, *) {
                Button(role: .close) {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
            } else {
                Button(role: .destructive) {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
            }
        }

        ToolbarItem {
            favouriteButton
        }

        // Sdílení rozdělaného timeru – dřív šlo sdílet jen uložený oblíbený
        // nebo preset, takže uživatel musel nejdřív ukládat.
        if TimerShareSheet.url(for: timer.settings) != nil {
            ToolbarItem {
                Button {
                    TimerShareSheet.present(settings: timer.settings, origin: .settings)
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }

        if #available(iOS 26.0, *) {
            ToolbarSpacer(.fixed)
        }

        if timer.canAddInterval {
            ToolbarItem {
                Button(action: addInterval) {
                    Image(systemName: "plus")
                }
            }
        }

        ToolbarItem {
            Button {
                editMode = (editMode == .active ? .inactive : .active)
            } label: {
                Image(systemName: "slider.horizontal.3")
            }
        }
    }

    /// Hvězdička v toolbaru podle stavu uložení:
    ///
    /// - neuloženo → prázdná hvězdička, uloží timer do oblíbených,
    /// - uloženo → plná, menu s přejmenováním a odebráním,
    /// - upraveno → plná s tečkou, menu s uložením změn, uložením
    ///   jako nový a vrácením uloženého.
    @ViewBuilder
    var favouriteButton: some View {
        switch saveState {
        case .unsaved:
            Button(action: askForNewFavouriteName) {
                Image(systemName: "star")
            }

        case .saved(let favourite):
            Menu {
                Button {
                    renamedTimerName = favourite.name
                    showRenameAlert = true
                } label: {
                    Label("RENAME_FAVOURITE", systemImage: "pencil")
                }
                Button(role: .destructive) {
                    viewModel.remove(favourite)
                } label: {
                    Label("REMOVE_FROM_FAVOURITES", systemImage: "star.slash")
                }
            } label: {
                Image(systemName: "star.fill")
            }

        case .modified(let favourite):
            Menu {
                Button {
                    viewModel.saveChanges()
                } label: {
                    Label("SAVE_CHANGES_TO \(favourite.name)", systemImage: "square.and.arrow.down")
                }
                Button(action: askForNewFavouriteName) {
                    Label("SAVE_AS_NEW", systemImage: "plus")
                }
                Button(role: .destructive) {
                    withAnimation { viewModel.revertChanges() }
                } label: {
                    Label("REVERT_TO_SAVED", systemImage: "arrow.uturn.backward")
                }
            } label: {
                Image(systemName: "star.fill")
                    .overlay(alignment: .topTrailing) {
                        Circle()
                            .fill(Color.gustavPink)
                            .frame(width: 7, height: 7)
                            .offset(x: 3, y: -2)
                    }
            }
        }
    }
}

// MARK: - Akce

private extension SettingsView {

    /// Binding na jednu volbu aktivního timeru. Zápis jde přes ViewModel,
    /// který ho hned uloží a pošle do analytiky.
    ///
    ///     Toggle("HAPTICS", isOn: setting(\.isVibrating, tracking: "haptics"))
    func setting<Value>(
        _ keyPath: ReferenceWritableKeyPath<TimerData, Value>,
        tracking name: String? = nil
    ) -> Binding<Value> {
        Binding(
            get: { timer[keyPath: keyPath] },
            set: { viewModel.update(keyPath, to: $0, tracking: name) }
        )
    }

    func addInterval() {
        withAnimation(.easeInOut) { viewModel.addInterval() }
    }

    /// Dialog startuje se stávajícím názvem, ať ho uživatel nemusí psát
    /// znovu – stačí ho upravit nebo potvrdit.
    func askForNewFavouriteName() {
        newTimerName = timer.name
        showSaveAlert = true
    }

    /// Pushne obrazovku vyžádanou odkazem (`gustavtimerapp://settings/…`).
    /// Nahradí, co je zrovna otevřené, ať uživatel skončí přesně na ní
    /// a zpět se vrátí do kořene nastavení.
    func openPendingScreen() {
        guard let screen = navigator.consume() else { return }
        path = [screen]
    }
}

private struct DismissKeyboardOnTap: UIViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        guard context.coordinator.tap == nil else { return }
        DispatchQueue.main.async {
            guard context.coordinator.tap == nil, let window = uiView.window else { return }
            let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.dismiss))
            tap.cancelsTouchesInView = false
            tap.delegate = context.coordinator
            window.addGestureRecognizer(tap)
            context.coordinator.tap = tap
        }
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        if let tap = coordinator.tap {
            tap.view?.removeGestureRecognizer(tap)
            coordinator.tap = nil
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var tap: UITapGestureRecognizer?

        @objc func dismiss() {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            var view = touch.view
            while let v = view {
                if v is UITextField { return false }
                view = v.superview
            }
            return true
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            return true
        }
    }
}

private struct ButtonLink: View {
    let label: LocalizedStringKey
    let URLString: String
    /// Hodnota `target` v signálu `link.opened`.
    let target: String

    var body: some View {
        Button(label) {
            if let url = URL(string: URLString) {
                Analytics.send(.externalLinkOpened, parameters: ["target": target])
                UIApplication.shared.open(url)
            }
        }
        .foregroundStyle(Color.gustavPink)
    }
}

#Preview("Light") {
    SettingsView(context: PreviewData.container.mainContext)
        .modelContainer(PreviewData.container)
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    SettingsView(context: PreviewData.container.mainContext)
        .modelContainer(PreviewData.container)
        .preferredColorScheme(.dark)
}
