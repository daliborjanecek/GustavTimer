//
//  TimerView.swift
//  GustavTimer
//
//  Created by Dalibor Janeček on 26.07.2025.
//

import SwiftUI
import SwiftData
import UIKit
import Lottie
import GustavUICore
import GustavUIAnimations

struct TimerView: View {
    @Binding var showSettings: Bool
    @Environment(\.modelContext) var context
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
        .onOpenURL { url in
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
        Group {
            if viewModel.isCountingDown {
                Text("\(viewModel.countdownValue)")
                    .font(.timerCountdown)
                    .foregroundColor(Color.gustavVolt)

            } else {
                Text(viewModel.formattedCurrentTime(timeDisplayFormat: timeDisplayFormat))
                    .font(.timerCounter)
                    .foregroundColor(Color.gustavVolt)
            }
        }
        .minimumScaleFactor(0.01)
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
    
    var startStopButton: some View {
        let isBeforeFirstStart = !viewModel.isTimerRunning && viewModel.finishedRounds == 0
        return ControlButton(
            action: viewModel.startStopTimer,
            label: viewModel.isTimerRunning ? "STOP" : (isBeforeFirstStart && viewModel.hasCountdown ? "COUNTDOWN" : "START"),
            description: orientation.isLandscape ? nil : startButtonDescription.map { LocalizedStringKey($0) },
            color: viewModel.isTimerRunning ? .gustavPink : .gustavVolt,
            buttonType: .constant(.text)
        )
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
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [CustomImageModel.self, TimerData.self])
}
