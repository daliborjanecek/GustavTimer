//
//  SettingsSheet.swift
//  GustavTimer
//
//  Created by Dalibor Janeček on 10.11.2025.
//

import SwiftUI
import SwiftData
import GustavUICore

struct SettingsView: View {
    @Query(sort: \TimerData.id, order: .reverse) private var timerData: [TimerData]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var editMode: EditMode = .inactive
    @State private var newTimerName = ""
    @State private var showSaveAlert = false
    @State private var renamedTimerName = ""
    @State private var showRenameAlert = false
    @State private var cachedLastSavedTimers: [TimerData] = []
    @ObservedObject private var remoteContent = RemoteContentManager.shared
    @ObservedObject private var navigator = AppNavigator.shared
    /// Obrazovky otevřené odkazem (`AppNavigator`) nebo z menu nastavení.
    @State private var path: [AppScreen] = []
    #if DEBUG
    @State private var showDebugMenu = false
    #endif
    
    private var currentTimerData: TimerData {
        getOrCreateTimerData()
    }

    /// Uložené oblíbené (bez hlavního timeru).
    private var favouriteTimers: [TimerData] {
        timerData.filter { $0.order > AppConfig.mainTimerOrder }
    }

    /// Je aktivní timer uložený v oblíbených, a jsou uložené i jeho úpravy?
    private var saveState: FavouriteTimers.SaveState {
        FavouriteTimers.state(main: currentTimerData, favourites: favouriteTimers)
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
//                about
            }
            .listSectionSpacing(24)
            .scrollDismissesKeyboard(.immediately)
            .background(DismissKeyboardOnTap())
            .environment(\.editMode, $editMode)
            .saveTimerAlert(isPresented: $showSaveAlert, timerName: $newTimerName, onSave: saveTimer)
            .renameTimerAlert(isPresented: $showRenameAlert, timerName: $renamedTimerName, onRename: renameFavourite)
            .toolbar { toolbar }
            .font(.gustavBody)
            .onAppear {
                refreshLastSavedTimers()
                openPendingScreen()
            }
            // Přibyl nebo zmizel oblíbený – výběr pořadí nemění, ten se
            // schválně přepočítá až při dalším otevření.
            .onChange(of: favouriteTimers.count) { _, _ in
                refreshLastSavedTimers()
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
    
    @ViewBuilder
    var timerNameView: some View {
        SettingsSection(label: "TIMER_NAME", footer: saveStateDescription) {
            TextField("TIMER_NAME_PROMPT", text: timerNameBinding)
                .font(.settingsIntervalName)
                .submitLabel(.done)
        }
    }

    /// Popis stavu uložení pod názvem timeru.
    private var saveStateDescription: LocalizedStringKey {
        switch saveState {
        case .unsaved: return "STATE_UNSAVED"
        case .saved: return "STATE_SAVED"
        case .modified: return "STATE_MODIFIED"
        }
    }

    /// Název timeru se ořezává na `AppConfig.maxTimerTitle`, aby přežil
    /// průchod sdíleným odkazem bez tichého zkrácení.
    ///
    /// Zápis se schválně neukládá explicitně – stejně jako u názvů intervalů
    /// se spoléhá na autosave SwiftData. `try? context.save()` při každém
    /// stisku klávesy by byl zbytečný zápis na disk.
    private var timerNameBinding: Binding<String> {
        Binding(
            get: { currentTimerData.name },
            set: { newValue in
                currentTimerData.name = String(newValue.prefix(AppConfig.maxTimerTitle))
            }
        )
    }

    @ViewBuilder
    var intervalsView: some View {
        Section {
            ForEach(currentTimerData.intervals) { interval in
                IntervalRowView(intervalName: Binding(
                    get: { interval.name },
                    set: { newValue in
                        let limited = String(newValue.prefix(AppConfig.maxTimerName))
                        updateIntervalName(limited, for: interval.id, in: currentTimerData)
                    }
                ), intervalValue: Binding(
                    get: { interval.value },
                    set: { newValue in
                        updateIntervalValue(newValue, for: interval.id, in: currentTimerData)
                    }
                ))
            }
            .onDelete(perform: currentTimerData.intervals.count > 1 ? { indexSet in
                deleteInterval(at: indexSet, from: currentTimerData)
            } : nil)
            .onMove { moveInterval(from: $0, to: $1, in: currentTimerData) }
        } header: {
            Text("INTERVALS_TAB")
                .font(.sectionHeader)
                .foregroundStyle(Color.gustavNeutral)
        } footer: {
            HStack(alignment: .top, spacing: 16) {
                if currentTimerData.intervals.count < AppConfig.maxTimerCount {
                    Text(summaryText)
                        .font(.sectionFooter)
                        .foregroundStyle(Color.gustavNeutral)
                        .multilineTextAlignment(.leading)
                    Spacer()
                    GustavSmallPillButton(label: "ADD_INTERVAL") {
                        addInterval(to: currentTimerData)
                    }
                    .padding(.leading, -16)
                } else {
                    Text(summaryText + " " + String(format: NSLocalizedString("MAX_LIMIT_REACHED", comment: ""), AppConfig.maxTimerCount))
                        .font(.sectionFooter)
                        .foregroundStyle(Color.gustavNeutral)
                    Spacer()
                }
            }
        }
    }
    
    var roundsView: some View {
        Section {
            NavigationLink {
                RoundsSettingsView(rounds: setting(\.rounds, tracking: "rounds"))
            } label: {
                ListButton(name: "ROUNDS", value: "\(currentTimerData.rounds == -1 ? "LOOP" : String(currentTimerData.rounds))")
            }
        }
    }
    
    @ViewBuilder
    private var favourites: some View {
        SettingsSection(label: "FAVOURITES") {
            let lastSavedTimers = cachedLastSavedTimers.prefix(3)
            if !lastSavedTimers.isEmpty {
                ForEach(lastSavedTimers) { timer in
                    let isSelected = timer.id == currentTimerData.sourceID
                    FavouriteRowView(
                        settings: timer.settings,
                        selected: isSelected,
                        isModified: isSelected && saveState.isModified,
                        isMinimized: true
                    )
                        .onTapGesture {
                            DispatchQueue.main.async {
                                withAnimation {
                                    selectTimer(timer: timer)
                                }
                            }
                        }
                }
            }
            NavigationLink {
                FavouritesView()
            } label: {
                Text("ALL_FAVOURITES")
            }
        }
    }
    
    @ViewBuilder
    private var feedback: some View {
        SettingsSection(label: "FEEDBACK", footer: "FEEDBACK_DESCRIPTION") {
            Toggle("HAPTICS", isOn: setting(\.isVibrating, tracking: "haptics"))
                .tint(Color.gustavVolt)

            Toggle("SET_COUNTDOWN", isOn: setting(\.hasCountdown, tracking: "countdown"))
                .tint(Color.gustavVolt)

            NavigationLink {
                TickingSettingsView(ticking: setting(\.ticking, tracking: "ticking"))
            } label: {
                ListButton(name: "SET_TICKING", value: currentTimerData.ticking.title)
            }

            NavigationLink {
                SoundSettingsView(selectedSound: setting(\.selectedSound))
            } label: {
                ListButton(name: "SOUND", value: currentTimerData.selectedSound?.title ?? "MUTE")
            }
        }
    }
    
    @ViewBuilder
    private var appearance: some View {
        SettingsSection(label: "APPEARANCE") {
            NavigationLink(value: AppScreen.background) {
                ListButton(name: "BACKGROUND")
            }
        }
    }
    
    /// Odkazy z API (včetně nástěnky nápadů). Když žádný platný odkaz z API
    /// není, ukáže se vestavěné „Ohodnoť“.
    @ViewBuilder
    private var more: some View {
        SettingsSection(label: "MORE") {
            let remoteLinks = remoteContent.links

            ForEach(remoteLinks) { link in
                Button(link.label) {
                    Analytics.send(.externalLinkOpened, parameters: ["target": "remote_link", "link_id": link.id])
                    AppLinkRouter.open(link.url)
                }
                .foregroundStyle(Color.gustavPink)
            }

            if remoteLinks.isEmpty {
                ButtonLink(label: "RATE", URLString: AppConfig.reviewURL, target: "rate")
            }
        }
    }

    #if DEBUG
    /// Číslo verze. Pětinásobné klepnutí otevře vývojářské menu – jen v DEBUG.
    private var debugEntry: some View {
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

    private var appVersionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }
    #endif
    
    @ViewBuilder
    private var about: some View {
        NavigationLink {
            Text("About")
        } label: {
            Text("ABOUT_GUSTAV")
        }
    }
    
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
                // Fallback on earlier versions
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
        if TimerShareSheet.url(for: currentTimerData.settings) != nil {
            ToolbarItem {
                Button {
                    TimerShareSheet.present(settings: currentTimerData.settings, origin: .settings)
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        
        if #available(iOS 26.0, *) {
            ToolbarSpacer(.fixed)
        }
        
        if currentTimerData.intervals.count < AppConfig.maxTimerCount {
            ToolbarItem {
                Button {
                    addInterval(to: currentTimerData)
                } label: {
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
    private var favouriteButton: some View {
        switch saveState {
        case .unsaved:
            Button {
                askForNewFavouriteName()
            } label: {
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
                    removeFavourite(favourite)
                } label: {
                    Label("REMOVE_FROM_FAVOURITES", systemImage: "star.slash")
                }
            } label: {
                Image(systemName: "star.fill")
            }

        case .modified(let favourite):
            Menu {
                Button {
                    saveChanges()
                } label: {
                    Label("SAVE_CHANGES_TO \(favourite.name)", systemImage: "square.and.arrow.down")
                }
                Button {
                    askForNewFavouriteName()
                } label: {
                    Label("SAVE_AS_NEW", systemImage: "plus")
                }
                Button(role: .destructive) {
                    revertChanges()
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

    /// Dialog startuje se stávajícím názvem, ať ho uživatel nemusí psát
    /// znovu – stačí ho upravit nebo potvrdit.
    private func askForNewFavouriteName() {
        newTimerName = currentTimerData.name
        showSaveAlert = true
    }
    
    /// Binding na jedno pole aktivního timeru. Zápis rovnou uloží kontext,
    /// aby se nastavení neztratilo, když uživatel zavře Settings swipem.
    ///
    ///     Toggle("HAPTICS", isOn: setting(\.isVibrating, tracking: "haptics"))
    ///
    /// - Parameter tracking: název volby pro `settings.changed`; `nil` = neposílat
    ///   (zvuk má vlastní signál v `SoundSettingsView`).
    private func setting<Value>(
        _ keyPath: ReferenceWritableKeyPath<TimerData, Value>,
        tracking name: String? = nil
    ) -> Binding<Value> {
        Binding(
            get: { currentTimerData[keyPath: keyPath] },
            set: { newValue in
                currentTimerData[keyPath: keyPath] = newValue
                try? context.save()
                if let name {
                    Analytics.settingChanged(name, value: newValue)
                }
            }
        )
    }

    private func getOrCreateTimerData() -> TimerData {
        TimerData.mainTimer(in: context)
    }
    
    private func refreshLastSavedTimers() {
        let saved = favouriteTimers
            .sorted(by: { ($0.lastUsed ?? .distantPast) > ($1.lastUsed ?? .distantPast) })
        cachedLastSavedTimers = Array(saved)
    }

    /// Pushne obrazovku vyžádanou odkazem (`gustavtimerapp://settings/…`).
    /// Nahradí, co je zrovna otevřené, ať uživatel skončí přesně na ní
    /// a zpět se vrátí do kořene nastavení.
    private func openPendingScreen() {
        guard let screen = navigator.consume() else { return }
        path = [screen]
    }
    
    private func saveTimer() {
        let favourite = FavouriteTimers.saveAsNew(name: newTimerName, in: context)
        Analytics.timerSaved(favourite.settings, screen: .settings, mode: .new)
    }

    private func saveChanges() {
        FavouriteTimers.saveChanges(in: context)
        Analytics.timerSaved(currentTimerData.settings, screen: .settings, mode: .update)
    }

    private func revertChanges() {
        withAnimation {
            FavouriteTimers.revert(in: context)
        }
        Analytics.send(.timerReverted)
    }

    private func renameFavourite() {
        guard let favourite = saveState.source else { return }
        FavouriteTimers.rename(favourite, to: renamedTimerName, in: context)
        Analytics.settingChanged("favourite", value: "renamed")
    }

    private func removeFavourite(_ favourite: TimerData) {
        FavouriteTimers.remove(favourite, in: context)
        refreshLastSavedTimers()
        Analytics.settingChanged("favourite", value: "removed")
    }
    
    private func updateIntervalName(_ name: String, for intervalId: UUID, in timerData: TimerData) {
        if let index = timerData.intervals.firstIndex(where: { $0.id == intervalId }) {
            timerData.intervals[index].name = name
        }
    }
    
    private func updateIntervalValue(_ value: Int, for intervalId: UUID, in timerData: TimerData) {
        if let index = timerData.intervals.firstIndex(where: { $0.id == intervalId }) {
            timerData.intervals[index].value = value
        }
    }
    
    private func addInterval(to timerData: TimerData) {
        guard timerData.intervals.count < AppConfig.maxTimerCount else { return }
        withAnimation(.easeInOut) {
            timerData.intervals.append(IntervalData(value: 5, name: NSLocalizedString("ROUND", comment: "") + " \(timerData.intervals.count + 1)"))
        }
        Analytics.settingChanged("interval_added", value: timerData.intervals.count)
    }
    
    /// Odstranění intervalů podle indexu
    private func deleteInterval(at offsets: IndexSet, from timerData: TimerData) {
        withAnimation(.easeInOut) {
            timerData.intervals.remove(atOffsets: offsets)
        }
        Analytics.settingChanged("interval_removed", value: timerData.intervals.count)
    }
    
    /// Přesun intervalu na novou pozici
    private func moveInterval(from source: IndexSet, to destination: Int, in timerData: TimerData) {
        withAnimation(.easeInOut) {
            timerData.intervals.move(fromOffsets: source, toOffset: destination)
        }
    }
    
    private func selectTimer(timer: TimerData) {
        FavouriteTimers.load(timer, in: context)
        Analytics.favouriteSelected(timer, screen: .settings)
    }
    
    var summaryText: String {
        let roundTime = currentTimerData.intervals.reduce(0) { $0 + $1.value }
        var totalTime: Int? {
            if currentTimerData.rounds > 1 {
                return roundTime * currentTimerData.rounds
            } else {
                return nil
            }
        }
        
        if let totalTime {
            return String(format: NSLocalizedString("SUM_ROUND_AND_TIMER_DESCRIPTION", comment: ""), roundTime.asTime(), totalTime.asTime())
        } else {
            return String(format: NSLocalizedString("SUM_ROUND_DESCRIPTION", comment: ""), roundTime.asTime())
        }
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
    SettingsView()
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    SettingsView()
        .preferredColorScheme(.dark)
}
