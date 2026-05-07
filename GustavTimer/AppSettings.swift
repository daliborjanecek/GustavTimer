//
//  AppSettings.swift
//  GustavTimer
//
//  Created by Dalibor Janeček on 18.09.2025.
//

import SwiftUI
import Combine

class AppSettings: ObservableObject {
    @AppStorage("rounds") var rounds: Int = -1
    @AppStorage("isVibrating") var isVibrating: Bool = false
    @AppStorage("isSoundEnabled") var isSoundEnabled: Bool = true
    @AppStorage("isTicking") var isTicking: Bool = false

    
    func save(rounds: Int, isVibrating: Bool, isSoundEnabled: Bool) {
        self.rounds = rounds
        self.isVibrating = isVibrating
        self.isSoundEnabled = isSoundEnabled
    }
    
    func save(from timerData: TimerData) {
        self.rounds = timerData.rounds
        self.isVibrating = timerData.isVibrating
        if timerData.selectedSound != nil {
            self.isSoundEnabled = true
        } else {
            self.isSoundEnabled = false
        }
    }
}
