//
//  TimerData.swift
//  GustavTimer
//
//  Created by Dalibor Janeček on 26.07.2025.
//

import Foundation
import SwiftData
import SwiftUI

@Model
class TimerData: Equatable {
    
    var id: UUID = UUID()
    var name: String
    var isVibrating: Bool
    var selectedSound: SoundModel?
    var rounds: Int
    var order: Int
    var createdAt: Date = Date()
    var usedCount: Int = 0
    var lastUsed: Date? = nil
    
    var hasCountdown: Bool = true
    var intervals: [IntervalData] = [
        IntervalData(value: 30, name: "Work"),
        IntervalData(value: 15, name: "Rest")
    ]

    init(order: Int, name: String, rounds: Int, selectedSound: SoundModel? = nil, isVibrating: Bool) {
        self.order = order
        self.name = name
        self.selectedSound = selectedSound
        self.isVibrating = isVibrating
        self.rounds = rounds
    }
    
    init(order: Int, name: String, rounds: Int, selectedSound: SoundModel? = nil, isVibrating: Bool, intervals: [IntervalData]) {
        self.order = order
        self.name = name
        self.selectedSound = selectedSound
        self.isVibrating = isVibrating
        self.rounds = rounds
        self.intervals = intervals
    }
    
    static func == (lhs: TimerData, rhs: TimerData) -> Bool {
        return lhs.intervals == rhs.intervals
    }
    
    func selected() {
        usedCount += 1
        lastUsed = Date()
    }
}

