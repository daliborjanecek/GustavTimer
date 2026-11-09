//
//  GustavTimerApp.swift
//  GustavTimer
//
//  Created by Dalibor Janeček on 19.04.2023.
//

import SwiftUI
import SwiftData
import GustavUICore
import TelemetryDeck

@main
struct GustavTimerApp: App {
    
    init() {
        GustavDesign.registerFonts()
        
        // Před onboardingem – podle jeho klíče se pozná stávající uživatel.
        AnalyticsAcquisition.registerLaunch()

        let config = TelemetryDeck.Config(appID: "E2CAE467-D3DB-4D72-9B05-1F026C60E7B7")
        // Nastavení zařízení u každého signálu, ať se dají signály podle nich
        // filtrovat bez opakování v každém volání.
        config.defaultParameters = {
            let defaults = UserDefaults.standard
            let background = defaults.integer(forKey: AppPreferences.Key.backgroundIndex)
            return [
                "portrait_format": defaults.string(forKey: AppPreferences.Key.portraitTimeDisplayFormat)
                    ?? TimeDisplayFormat.seconds.rawValue,
                "landscape_format": defaults.string(forKey: AppPreferences.Key.landscapeTimeDisplayFormat)
                    ?? TimeDisplayFormat.minutesSecondsHundredths.rawValue,
                "background": background == -1 ? "custom" : "preset"
            ]
        }
        TelemetryDeck.initialize(config: config)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [CustomImageModel.self, TimerData.self])
    }
}
