//
//  ContentView.swift
//  GustavTimer
//
//  Created by Dalibor Janeček on 19.04.2023.
//

import SwiftUI
import StoreKit
import SwiftData
import TelemetryDeck

/// Modály nad timerem. SwiftUI umí na jednom view prezentovat jen jeden sheet
/// naráz, takže je držíme v jediném stavu – dřív se onboarding a „co je nového“
/// přetahovaly o prezentaci a po zavření prvního naskočil druhý.
enum AppSheet: Identifiable {
    case settings
    case onboarding
    case whatsNew

    var id: Self { self }
}

struct ContentView: View {
    @Environment(\.modelContext) var context
    
    @State private var activeSheet: AppSheet?
    @AppStorage(AppPreferences.Key.lastOnboardingVersion) private var lastOnboardingVersion: Int = 0

    var body: some View {
        TimerView(activeSheet: $activeSheet)
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .settings:
                    SettingsView()
                case .onboarding, .whatsNew:
                    OnboardingView()
                }
            }
            .onChange(of: activeSheet) { oldValue, newValue in
                trackSheetChange(from: oldValue, to: newValue)
            }
            .onAppear {
                initializeDataIfNeeded()
                SettingsMigration.runIfNeeded(context: context)
                showOnboardingIfNeeded()
            }
    }
    
    private func initializeDataIfNeeded() {
        TimerData.mainTimer(in: context)
        try? context.save()
    }

    /// Onboarding má přednost před „co je nového“ – po čisté instalaci se
    /// uživateli ukáže jen on.
    private func showOnboardingIfNeeded() {
        guard lastOnboardingVersion != AppConfig.onboardingVersion else { return }
        lastOnboardingVersion = AppConfig.onboardingVersion
        activeSheet = .onboarding
    }

    /// „Co je nového“ se počítá při zobrazení, onboarding při zavření.
    /// Onboarding nemá vlastní callback na dokončení (je ze sdíleného
    /// GustavUI), takže zavření tlačítkem i swipem se bere jako dokončení.
    private func trackSheetChange(from oldValue: AppSheet?, to newValue: AppSheet?) {
        if newValue == .whatsNew {
            Analytics.send(.whatsNewShown, parameters: ["version": String(AppConfig.version)])
        }
        if oldValue == .onboarding, newValue != .onboarding {
            TelemetryDeck.onboardingCompleted()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .modelContainer(for: [CustomImageModel.self, TimerData.self])
    }
}
