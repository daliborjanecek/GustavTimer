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
        
        let config = TelemetryDeck.Config(appID: "E2CAE467-D3DB-4D72-9B05-1F026C60E7B7")
        TelemetryDeck.initialize(config: config)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [CustomImageModel.self, TimerData.self])
    }
}
