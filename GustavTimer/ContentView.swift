//
//  ContentView.swift
//  GustavTimer
//
//  Created by Dalibor Janeček on 19.04.2023.
//

import SwiftUI
import StoreKit
import SwiftData

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
    @Query var timerData: [TimerData]
    
    @Environment(\.modelContext) var context
    
    @AppStorage("selectedBackgroundIndex") private var selectedBackgroundIndex: Int = 0
    @AppStorage("activeTimerId") private var activeTimerId: Int = 0
    @AppStorage("selectedSound") private var selectedSound: String = "beep"
    @AppStorage("isSoundEnabled") private var isSoundEnabled: Bool = true
    
    @State private var activeSheet: AppSheet?
    @AppStorage("lastOnboardingVersion") private var lastOnboardingVersion: Int = 0

    private var defaultTimerId: Int = 0

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
            .onAppear {
                initializeDataIfNeeded()
                showOnboardingIfNeeded()
            }
    }
    
    private func initializeDataIfNeeded() {
        if timerData.isEmpty {
            let defaultTimer = AppConfig.defaultTimer
            context.insert(defaultTimer)
            try? context.save()
        }
    }

    /// Onboarding má přednost před „co je nového“ – po čisté instalaci se
    /// uživateli ukáže jen on.
    private func showOnboardingIfNeeded() {
        guard lastOnboardingVersion != AppConfig.onboardingVersion else { return }
        lastOnboardingVersion = AppConfig.onboardingVersion
        activeSheet = .onboarding
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .modelContainer(for: [CustomImageModel.self, TimerData.self])
    }
}
