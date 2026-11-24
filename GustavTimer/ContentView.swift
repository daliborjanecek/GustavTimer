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
    @Environment(\.scenePhase) private var scenePhase
    
    @State private var activeSheet: AppSheet?
    @AppStorage(AppPreferences.Key.lastOnboardingVersion) private var lastOnboardingVersion: Int = 0

    var body: some View {
        TimerView(activeSheet: $activeSheet)
            .sheet(item: sheetBinding) { sheet in
                switch sheet {
                case .settings:
                    SettingsView(context: context)
                case .onboarding, .whatsNew:
                    OnboardingView()
                }
            }
            // Na iPadu je nastavení postranní panel vedle timeru – ten zůstává
            // vidět a úpravy se v něm projevují hned. V úzkém okně (Split View,
            // Slide Over) se panel sám promění v sheet.
            .inspector(isPresented: inspectorBinding) {
                SettingsView(context: context, onClose: { activeSheet = nil })
                    .inspectorColumnWidth(min: 340, ideal: 400, max: 520)
            }
            .onChange(of: activeSheet) { oldValue, newValue in
                trackSheetChange(from: oldValue, to: newValue)
            }
            .onAppear {
                initializeDataIfNeeded()
                SettingsMigration.runIfNeeded(context: context)
                showOnboardingIfNeeded()
            }
            // Spuštění i návrat do popředí: přepočítat platnost staženého
            // obsahu a případně ho na pozadí aktualizovat (nejvýš 1× za 24 h).
            .onChange(of: scenePhase, initial: true) { _, phase in
                if phase == .active {
                    RemoteContentManager.shared.handleBecameActive()
                }
            }
    }
    
    private var showsSettingsAsInspector: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    /// Sheet ukazuje všechno kromě nastavení na iPadu – to patří do panelu.
    private var sheetBinding: Binding<AppSheet?> {
        Binding(
            get: {
                showsSettingsAsInspector && activeSheet == .settings ? nil : activeSheet
            },
            set: { newValue in
                // Zavření sheetu nesmí shodit otevřený panel.
                if newValue == nil, showsSettingsAsInspector, activeSheet == .settings { return }
                activeSheet = newValue
            }
        )
    }

    private var inspectorBinding: Binding<Bool> {
        Binding(
            get: { showsSettingsAsInspector && activeSheet == .settings },
            set: { isPresented in
                if isPresented {
                    activeSheet = .settings
                } else if activeSheet == .settings {
                    activeSheet = nil
                }
            }
        )
    }

    private func initializeDataIfNeeded() {
        TimerData.mainTimer(in: context)
        FavouriteTimers.linkLegacySource(in: context)
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

#Preview {
    ContentView()
        .modelContainer(PreviewData.container)
}
