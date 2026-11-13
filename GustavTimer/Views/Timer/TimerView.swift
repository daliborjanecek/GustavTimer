//
//  TimerView.swift
//  GustavTimer
//
//  Created by Dalibor Janeček on 26.07.2025.
//

import SwiftUI
import SwiftData
import StoreKit
import UIKit
import Lottie
import GustavUICore
import GustavUIAnimations

struct TimerView: View {
    @Binding var activeSheet: AppSheet?
    @Environment(\.modelContext) var context
    @Environment(\.requestReview) var requestReview
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \TimerData.id, order: .reverse) private var timerData: [TimerData]
    @StateObject var viewModel = TimerViewModel()
    @State private var orientation = UIDeviceOrientation.unknown
    /// Animace ikon v hlavičce – zvuk a vibrace bliknou při přechodu
    /// intervalu, smyčka při dokončení kola.
    @State private var feedbackIconAnimation = LottiePlaybackMode.paused(at: .frame(0))
    @State private var loopIconAnimation = LottiePlaybackMode.paused(at: .frame(0))
    @AppStorage(AppPreferences.Key.portraitTimeDisplayFormat) private var portraitFormat: TimeDisplayFormat = .seconds
    @AppStorage(AppPreferences.Key.landscapeTimeDisplayFormat) private var landscapeFormat: TimeDisplayFormat = .minutesSecondsHundredths

    
    var body: some View {
        ZStack {
            BackgroundImageView()
            if orientation.isLandscape {
                landscapeTimerView
            } else {
                portraitTimerView
            }
        }
        .onAppear {
            setupViewModel()
        }
        .onChange(of: activeSheet) { oldValue, newValue in
            // Otevření nastavení timer nezastaví – viz TimerViewModel.settingsEdited.
            if oldValue == .settings, newValue != .settings {
                viewModel.settingsClosed(TimerData.mainTimer(in: context).settings)
            }
        }
        .onChange(of: mainTimerSettings) { _, newSettings in
            // Úpravy v otevřeném nastavení se do TimerData propisují hned
            // (i bez uložení kontextu), takže tady je vidíme při každé změně.
            guard activeSheet == .settings, let newSettings else { return }
            viewModel.settingsEdited(newSettings)
        }
        .onAppear {
            orientation = UIDevice.current.orientation
        }
        // `onReceive` se odhlásí samo. Dřívější blokový observer se
        // `removeObserver(self)` odregistrovat nedal a zůstával viset.
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            // Poloha „displejem nahoru/dolů“ rozložení nemění.
            let current = UIDevice.current.orientation
            if current.isValidInterfaceOrientation {
                orientation = current
            }
        }
        .onChange(of: viewModel.intervalPulse) { _, _ in
            feedbackIconAnimation = .playing(.fromProgress(0, toProgress: 1, loopMode: .playOnce))
        }
        .onChange(of: viewModel.roundPulse) { _, _ in
            loopIconAnimation = .playing(.fromProgress(0, toProgress: 1, loopMode: .playOnce))
        }
        .onChange(of: portraitFormat) { _, format in
            trackDisplayFormat(format, orientation: "portrait")
        }
        .onChange(of: landscapeFormat) { _, format in
            trackDisplayFormat(format, orientation: "landscape")
        }
        .onChange(of: scenePhase) { _, newPhase in
            // Návrat z pozadí srovná odpočet s reálným časem.
            viewModel.handleScenePhase(newPhase)
        }
        .onOpenURL { url in
            // Universal Link i historické gustavtimerapp:// chodí sem.
            // Normalizaci obou tvarů dělá SharedTimerLink.route, ať neexistují
            // dvě větve, které se můžou rozejít.
            viewModel.handleDeepLink(url: url)
        }
        .onReceive(NotificationCenter.default.publisher(for: AppLinkRouter.internalLinkNotification)) { notification in
            // Odkaz na timer z banneru v nastavení – viz AppLinkRouter.
            guard let url = notification.object as? URL else { return }
            viewModel.handleDeepLink(url: url, fromApp: true)
        }
        .onChange(of: viewModel.pendingSharedLink?.id) { _, id in
            // Timer z externího odkazu se načte až po potvrzení.
            guard id != nil, let pending = viewModel.pendingSharedLink else { return }
            SharedLinkPrompt.present(
                pending.link,
                onLoad: { viewModel.confirmPendingSharedLink() },
                onCancel: { viewModel.declinePendingSharedLink() }
            )
        }
        .onReceive(AppNavigator.shared.$pendingScreen) { screen in
            // Obrazovka v nastavení (gustavtimerapp://settings/…). Otevřené
            // nastavení si ji převezme samo, jinak ho tady otevřeme.
            guard screen != nil, activeSheet != .settings else { return }
            present(.settings)
        }
    }
}

// MARK: - Orientation Handling
private extension TimerView {
    
    
    var portraitTimerView: some View {
        VStack {
            ProgressArrayView(
                intervals: viewModel.timers,
                activeIndex: viewModel.activeTimerIndex,
                progress: viewModel.progress
            )
                .padding(.top)
            
            headerSection
            
            Spacer()
            
            counterDisplay(format: $portraitFormat, formats: [.seconds, .minutesSeconds])
            
            Spacer()
            
            horizontalControlButtons
        }
        .ignoresSafeArea(edges: .bottom)
        .statusBar(hidden: true)
        .persistentSystemOverlays(.hidden)
    }
    
    var landscapeTimerView: some View {
        VStack {
            Spacer()
            
            counterDisplay(format: $landscapeFormat, formats: [.minutesSecondsHundredths, .seconds])
            
            Spacer()
        }
        .statusBar(hidden: true)
        .persistentSystemOverlays(.hidden)
        // Na šířku nejsou tlačítka – timer se ovládá jen tapy.
        .playbackTaps(onTap: { viewModel.startStopTimer(input: .landscapeTap) }, onDoubleTap: skipIfRunning)
    }
}

// MARK: - View Components
private extension TimerView {
    
    var headerSection: some View {
        HStack {
            currentTimerInfo
            Spacer()
            settingsButton
        }
        .font(.headUpDisplay)
    }
    
    @ViewBuilder
    var currentTimerInfo: some View {
        if currentTimer != nil {
            Text(headerLabel)
                .safeAreaPadding(.horizontal)
                .foregroundColor(Color.gustavVolt)
                .lineLimit(1)
                .animation(.easeInOut(duration: 0.2), value: viewModel.finishedRounds)
        } else {
            Text("No Timer")
                .safeAreaPadding(.horizontal)
                .foregroundColor(Color.gustavVolt.opacity(0.5))
        }
    }

    /// Dokud timer neběží, je tu název timeru – dřív tady bylo prázdno
    /// (text se schovával přes `opacity(0)`). Po startu ho vystřídá aktuální
    /// interval a počet odběhnutých kol.
    var headerLabel: String {
        guard let currentTimer else { return "" }
        guard viewModel.finishedRounds > 0 else { return viewModel.settings.name }

        let rounds = viewModel.settings.rounds == -1
            ? ""
            : "/" + String(viewModel.settings.rounds)
        return "\(currentTimer.name) (\(viewModel.finishedRounds)\(rounds))"
    }
    
    /// Velký odpočet jako stránkovaný `TabView` – každá stránka je jeden formát
    /// času a swipe mezi nimi listuje s animací jako mezi taby. Vybraná stránka
    /// se pamatuje pro každou orientaci zvlášť; první v `formats` je výchozí.
    ///
    /// Tap spustí/zastaví timer, dvojtap přeskočí interval. Na tap reaguje jen
    /// samotné číslo; swipe mezi formáty funguje v celé volné ploše. Na šířku
    /// tapy navíc zachytává celý view (`landscapeTimerView`).
    ///
    /// Na šířku zasahuje bezpečná zóna (výřez, zaoblené rohy) do stran, takže
    /// stránkovaný view by končil před okrajem displeje a při swipu by byly
    /// vidět jeho hrany. `TabView` proto sahá až k okrajům a dovnitř stránky
    /// se bezpečná zóna vrací jen jako odsazení čísla.
    func counterDisplay(format: Binding<TimeDisplayFormat>, formats: [TimeDisplayFormat]) -> some View {
        GeometryReader { geometry in
            let insets = geometry.safeAreaInsets
            TabView(selection: format) {
                ForEach(formats, id: \.self) { pageFormat in
                    Text(viewModel.formattedCurrentTime(timeDisplayFormat: pageFormat))
                        .font(.timerCounter)
                        .minimumScaleFactor(0.01)
                        .foregroundColor(Color.gustavVolt)
                        // Tap jen na samotném čísle – ne na celé volné ploše,
                        // která by na výšku sahala k progressbaru i k tlačítkům.
                        .contentShape(Rectangle())
                        .playbackTaps(onTap: { startStopByTap() }, onDoubleTap: skipIfRunning)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.leading, insets.leading)
                        .padding(.trailing, insets.trailing)
                        // Stránka si případně bezpečnou zónu nedopočítá znovu
                        // – odsazení výše by se jinak zdvojilo.
                        .ignoresSafeArea(edges: .horizontal)
                        .background(PagingSafeAreaInsetFix())
                        .tag(pageFormat)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea(edges: .horizontal)
        }
        .sensoryFeedback(.selection, trigger: format.wrappedValue)
    }
    
    var horizontalControlButtons: some View {
        HStack(spacing: 16) {
            startStopButton
            secondaryButton
                .frame(width: 100)
        }
        .animation(.easeInOut, value: viewModel.isTimerRunning)
        .frame(maxWidth: .infinity)
        .padding()
        .padding(.bottom, 5)
        .padding(.horizontal, 5)
    }
    
    @ViewBuilder
    var startStopButton: some View {
        if viewModel.isCountingDown {
            CountdownStartButton(
                countdownValue: viewModel.countdownValue,
                countdownDuration: AppConfig.countdownDuration,
                action: { viewModel.startStopTimer(input: .button) }
            )
        } else {
            let isBeforeFirstStart = !viewModel.isTimerRunning && viewModel.finishedRounds == 0
            ControlButton(
                label: isBeforeFirstStart && viewModel.hasCountdown ? "COUNTDOWN" : (viewModel.isTimerRunning ? "STOP" : "START"),
                description: orientation.isLandscape ? nil : startButtonDescription.map { LocalizedStringKey($0) },
                color: viewModel.isTimerRunning ? .gustavPink : .gustavVolt,
                action: { viewModel.startStopTimer(input: .button) }
            )
        }
    }
    
    var secondaryButton: some View {
        ControlButton(
            icon: viewModel.isTimerRunning ? .skip : .reset,
            color: .gustavNeutral,
            action: viewModel.isTimerRunning ? viewModel.skipLap : viewModel.resetTimer
        )
    }
    
    var settingsButton: some View {
        Button {
            present(.settings)
        } label: {
            HStack {
                settingsIcons
                Text("EDIT")
            }
            .foregroundColor(Color.gustavVolt)
        }
        .safeAreaPadding(.horizontal)
    }
    
    var settingsIcons: some View {
        HStack {
            if viewModel.settings.rounds == -1 {
                GustavAnimationView(.loop, mode: $loopIconAnimation)
                    .frame(width: 20, height: 20)
            }
            
            if viewModel.settings.isVibrating {
                GustavAnimationView(.vibration, mode: $feedbackIconAnimation)
                    .frame(width: 20, height: 20)
            }
            
            if viewModel.settings.sound != nil {
                GustavAnimationView(.sound, mode: $feedbackIconAnimation)
                    .frame(width: 20, height: 20)
            }
        }
        .frame(height: 20)
    }
}

// MARK: - Computed Properties
private extension TimerView {
    
    /// Nastavení hlavního timeru tak, jak ho právě upravuje SettingsView.
    var mainTimerSettings: TimerSettings? {
        timerData.first { $0.order == AppConfig.mainTimerOrder }?.settings
    }

    var currentTimer: IntervalData? {
        guard viewModel.activeTimerIndex < viewModel.timers.count else { return nil }
        return viewModel.timers[viewModel.activeTimerIndex]
    }
    
    var startButtonDescription: String? {
        guard !viewModel.isTimerRunning, let currentTimer = currentTimer else { return nil }
        guard !viewModel.hasCountdown || viewModel.finishedRounds > 0 else { return nil }
        return currentTimer.name
    }
}

// MARK: - Helper Methods
private extension TimerView {
    
    /// Prezentace sheetu. Když už nějaký běží, musí se nejdřív doopravdy zavřít,
    /// jinak SwiftUI ten nový neukáže.
    func present(_ sheet: AppSheet) {
        guard activeSheet != nil, activeSheet != sheet else {
            activeSheet = sheet
            return
        }
        activeSheet = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            activeSheet = sheet
        }
    }

    /// Dvojtap na odpočtu přeskočí interval jen za běhu – stejně jako tlačítko,
    /// které se na skip mění až po startu. Stojící timer by skip „uschoval“
    /// a interval by po startu zmizel.
    /// Tap na odpočet. Odpočet je na výšku i na šířku stejný view, takže
    /// orientaci rozliší až tady.
    func startStopByTap() {
        viewModel.startStopTimer(input: orientation.isLandscape ? .landscapeTap : .tap)
    }

    func trackDisplayFormat(_ format: TimeDisplayFormat, orientation: String) {
        Analytics.send(.displayFormatChanged, parameters: [
            "orientation": orientation,
            "format": format.rawValue
        ])
    }

    func skipIfRunning() {
        guard viewModel.isTimerRunning else { return }
        viewModel.skipLap()
    }

    func setupViewModel() {
        // Callbacky dřív než `showWhatsNew`, které jeden z nich volá.
        viewModel.onPresentSheet = { present($0) }
        viewModel.onReviewRequested = { requestReview() }
        viewModel.setModelContext(context)
        viewModel.showWhatsNew()
    }
}

private extension View {
    /// Tap = start/stop, dvojtap = skip. Dvojtap musí být deklarovaný první,
    /// jinak by ho SwiftUI nikdy nerozpoznalo – jednoduchý tap proto čeká,
    /// jestli nepřijde druhý, a spustí se se zpožděním asi 0,3 s.
    func playbackTaps(onTap: @escaping () -> Void, onDoubleTap: @escaping () -> Void) -> some View {
        onTapGesture(count: 2, perform: onDoubleTap)
            .onTapGesture(perform: onTap)
    }
}

/// Stránkovaný `TabView` stojí na UIKitovém scroll view. Když sahá přes
/// bezpečnou zónu (na šířku kvůli výřezu), scroll view si ji automaticky
/// přidá do insetů obsahu. Po odpružení na první/poslední stránce se pak
/// usadí o šířku bezpečné zóny vedle a číslo zůstane vyosené.
///
/// Tenhle prázdný view se vloží do stránky, najde nejbližší nadřazený
/// scroll view a automatické insety mu vypne – bezpečnou zónu si stránka
/// řeší sama odsazením čísla.
private struct PagingSafeAreaInsetFix: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        FixView()
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    private final class FixView: UIView {
        override func didMoveToWindow() {
            super.didMoveToWindow()
            isUserInteractionEnabled = false
            var view = superview
            while let current = view {
                if let scrollView = current as? UIScrollView {
                    scrollView.contentInsetAdjustmentBehavior = .never
                    return
                }
                view = current.superview
            }
        }
    }
}

private struct CountdownStartButton: View {
    let countdownValue: Int
    let countdownDuration: Int
    let action: () -> Void

    @State private var animatedProgress: Double = 0

    var body: some View {
        Button(action: action) {
            ZStack {
                Color.gustavVolt

                GeometryReader { geo in
                    Color.gustavPink
                        .frame(width: geo.size.width * animatedProgress)
                        .opacity(min(1.0, animatedProgress + 0.5))
                }

                Text("\(countdownValue)")
                    .font(.buttonLabel)
                    .foregroundStyle(animatedProgress > 0.5 ? Color.gustavVolt : Color.gustavNeutral)
                    .frame(maxWidth: .infinity)
            }
            .frame(height: GustavLayout.controlHeight)
            .clipShape(Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onAppear {
            let target = Double(countdownDuration - countdownValue + 1) / Double(countdownDuration)
            withAnimation(.linear(duration: 1.01)) {
                animatedProgress = target
            }
        }
        .onChange(of: countdownValue) { _, newValue in
            let target = Double(countdownDuration - newValue + 1) / Double(countdownDuration)
            withAnimation(.linear(duration: 1.0)) {
                animatedProgress = target
            }
        }
    }
}

#Preview("Timer") {
    TimerView(activeSheet: .constant(nil))
        .modelContainer(PreviewData.container)
}

#Preview("Tlačítko odpočtu") {
    CountdownStartButton(countdownValue: 2, countdownDuration: 3, action: {})
        .padding()
        .background(.black)
}
