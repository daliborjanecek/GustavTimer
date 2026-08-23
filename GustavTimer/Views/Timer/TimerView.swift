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
    @Binding var showSettings: Bool
    @Binding var showWhatsNew: Bool
    @Environment(\.modelContext) var context
    @Environment(\.requestReview) var requestReview
    @Query(sort: \TimerData.id, order: .reverse) private var timerData: [TimerData]
    @StateObject var viewModel = TimerViewModel()
    @State private var orientation = UIDeviceOrientation.unknown

    
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
        .onChange(of: showSettings) { _, newValue in
            if newValue {
                // SettingsView se otevírá, zastavit časovač
                viewModel.stopTimer()
            } else {
                // SettingsView se zavřelo, znovu načti data z databáze a resetuj časovač
                viewModel.reloadTimers(resetCurrentState: true)
                viewModel.setSound(sound: timerData.first(where: { $0.order == 0 })?.selectedSound)
            }
        }
        .onAppear {
            // Nastavíme počáteční orientaci
            orientation = UIDevice.current.orientation
            // Zaregistrujeme se pro notifikace o změně orientace
            NotificationCenter.default.addObserver(
                forName: UIDevice.orientationDidChangeNotification,
                object: nil,
                queue: .main) { _ in
                    if UIDevice.current.orientation.isValidInterfaceOrientation {
                        orientation = UIDevice.current.orientation
                    }
                }
        }
        .onDisappear {
            // Odregistrujeme notifikace
            NotificationCenter.default.removeObserver(
                self,
                name: UIDevice.orientationDidChangeNotification,
                object: nil)
        }
        .onChange(of: viewModel.showingSheet) { _, newValue in
            if newValue {
                showSettings = true
                viewModel.showingSheet = false
            }
        }
        .onChange(of: viewModel.showingWhatsNew) { _, newValue in
            if newValue {
                viewModel.showingWhatsNew = false
                if showSettings {
                    showSettings = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showWhatsNew = true
                    }
                } else {
                    showWhatsNew = true
                }
            }
        }
        .onOpenURL { url in
            // Universal Link i historické gustavtimerapp:// chodí sem.
            // Normalizaci obou tvarů dělá SharedTimerLink.route, ať neexistují
            // dvě větve, které se můžou rozejít.
            viewModel.handleDeepLink(url: url)
        }
    }
}

// MARK: - Orientation Handling
private extension TimerView {
    
    
    var portraitTimerView: some View {
        VStack {
            ProgressArrayView(viewModel: viewModel)
                .padding(.top)
            
            headerSection
            
            Spacer()
            
            counterDisplay(timeDisplayFormat: .seconds)
            
            Spacer()
            
            horizontalControlButtons
        }
        .ignoresSafeArea(edges: .bottom)
        .statusBar(hidden: true)
        .persistentSystemOverlays(.hidden)
    }
    
    var landscapeTimerView: some View {
        VStack {
            //            ProgressArrayView(viewModel: viewModel)
            //                .padding(.top)
            
            //            headerSection
            
            Spacer()
            
            counterDisplay(timeDisplayFormat: .minutesSecondsHundredths)
            
            Spacer()
        }
        //        .ignoresSafeArea(edges: .bottom)
        .statusBar(hidden: true)
        .persistentSystemOverlays(.hidden)
        .onTapGesture {
            viewModel.startStopTimer()
        }
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
        if let currentTimer = currentTimer {
            Text("\(currentTimer.name) (\(viewModel.finishedRounds)\(viewModel.rounds == -1 ? "" : ("/" + String(viewModel.rounds))))")
                .safeAreaPadding(.horizontal)
                .foregroundColor(Color.gustavVolt.opacity(viewModel.finishedRounds == 0 ? 0.0 : 1.0))
                .animation(.easeInOut(duration: 0.2), value: viewModel.finishedRounds)
        } else {
            Text("No Timer")
                .safeAreaPadding(.horizontal)
                .foregroundColor(Color.gustavVolt.opacity(0.5))
        }
    }
    
    func counterDisplay(timeDisplayFormat: TimeDisplayFormat) -> some View {
        Text(viewModel.formattedCurrentTime(timeDisplayFormat: timeDisplayFormat))
            .font(.timerCounter)
            .minimumScaleFactor(0.01)
            .foregroundColor(Color.gustavVolt)
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
    }
    
    var verticalControlButtons: some View {
        VStack(spacing: 16) {
            startStopButton
            secondaryButton
                .frame(width: 100)
        }
        .animation(.easeInOut, value: viewModel.isTimerRunning)
        .frame(maxWidth: .infinity)
        .padding()
    }
    
    @ViewBuilder
    var startStopButton: some View {
        if viewModel.isCountingDown {
            CountdownStartButton(
                countdownValue: viewModel.countdownValue,
                countdownDuration: AppConfig.countdownDuration,
                action: viewModel.startStopTimer
            )
        } else {
            let isBeforeFirstStart = !viewModel.isTimerRunning && viewModel.finishedRounds == 0
            ControlButton(
                action: viewModel.startStopTimer,
                label: isBeforeFirstStart && viewModel.hasCountdown ? "COUNTDOWN" : (viewModel.isTimerRunning ? "STOP" : "START"),
                description: orientation.isLandscape ? nil : startButtonDescription.map { LocalizedStringKey($0) },
                color: viewModel.isTimerRunning ? .gustavPink : .gustavVolt,
                buttonType: .constant(.text)
            )
        }
    }
    
    var secondaryButton: some View {
        ControlButton(
            action: viewModel.isTimerRunning ? viewModel.skipLap : viewModel.resetTimer,
            riveAnimation: "",
            color: .gustavNeutral,
            buttonType: .init(get: {
                viewModel.isTimerRunning ? .skip : .reset
            }, set: { _ in
                //
            })
        )
    }
    
    var settingsButton: some View {
        Button {
            showSettings.toggle()
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
            if viewModel.rounds == -1 {
                GustavAnimationView(.loop, mode: $viewModel.loopIconAnimation)
                    .frame(width: 20, height: 20)
            }
            
            if viewModel.isVibrating {
                GustavAnimationView(.vibration, mode: $viewModel.appearanceIconAnimation)
                    .frame(width: 20, height: 20)
            }
            
            if viewModel.isSoundEnabled {
                GustavAnimationView(.sound, mode: $viewModel.appearanceIconAnimation)
                    .frame(width: 20, height: 20)
            }
        }
        .frame(height: 20)
    }
    
    var soundIcon: some View {
        Image(systemName: viewModel.isSoundEnabled ? "speaker.wave.2.circle.fill" : "speaker.slash.circle.fill")
            .resizable()
            .scaledToFit()
            .foregroundColor(Color(viewModel.isSoundEnabled ? Color.gustavVolt : Color.gustavNeutral))
    }
}

// MARK: - Computed Properties
private extension TimerView {
    
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
    
    func setupViewModel() {
        viewModel.setModelContext(context)
        viewModel.showWhatsNew()
        viewModel.setSound(sound: timerData.first(where: { $0.order == 0 })?.selectedSound)
        viewModel.onReviewRequested = {
            requestReview()
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

                HStack(spacing: 8) {
//                    Text("COUNTDOWN")
//                        .font(.buttonLabel)
                    Text("\(countdownValue)")
                        .font(.buttonLabel)
                }
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

#Preview {
    ContentView()
        .modelContainer(for: [CustomImageModel.self, TimerData.self])
}
