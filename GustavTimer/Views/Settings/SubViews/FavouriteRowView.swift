//
//  FavouritesItemView.swift
//  GustavTimer
//
//  Created by Dalibor Janeček on 06.09.2025.
//

import SwiftUI
import GustavUICore

struct FavouriteRowView: View {
    let timer: TimerData
    let selected: Bool
    var isMinimized: Bool = false
    var tip: String? = nil
        
    var isMainTimer: Bool {
        timer.order == AppConfig.defaultTimer.order
    }
    
    var body: some View {
        VStack(spacing: 0) {
            GustavSelectableListRow(selected: selected) {
                    VStack(alignment: .leading, spacing: isMinimized ? 4 : 36) {
                        if !isMinimized {
                            GeometryReader { geometry in
                                HStack(alignment: .top, spacing: 5) {
                                    ForEach(timer.intervals) { interval in
                                        VStack(alignment: .leading) {
                                            Capsule()
                                                .fill(progressBarColor)
                                                .frame(height: isMinimized ? 4 : 5)
                                            Text(interval.name)
                                                .font(.savedRowIntervalName)
                                                .lineLimit(1)
                                                .padding(.trailing)
                                                .foregroundStyle(Color.gustavLight)
                                        }
                                        .frame(width: getIntervalWidth(interval: interval, viewWidth: geometry.size.width))
                                    }
                                }
                            }
                        }
                        HStack {
                            Text(intervalName)
                                .font(isMinimized ? .savedRowTimerNameMinimized : .savedRowTimerName)
                                .opacity(isMainTimer ? 0.4 : 1)
                                .lineLimit(1)
                                .padding(.trailing, 4)
                            
                            if !isMinimized {
                                if timer.rounds == -1 {
                                    GustavIcon(.loop, size: 22, color: Color.gustavLight)
                                }
                                
                                if timer.selectedSound != nil {
                                    GustavIcon(.sound, size: 22, color: Color.gustavLight)
                                }
                                
                                if timer.isVibrating {
                                    GustavIcon(.vibration, size: 22, color: Color.gustavLight)
                                }
                            }
                            
                            Spacer()
                        }
                    }

                }
            if let tip, !isMinimized {
                Text(tip)
                    .multilineTextAlignment(.leading)
                    .font(.settingsCaption)
                    .foregroundStyle(Color.gustavNeutral)
                    .padding()
                    .padding(.top, -8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
//        .padding()
    }
    
    var intervalName: LocalizedStringKey {
        if isMainTimer {
            return "CURRENT_TIMER"
        } else {
            return LocalizedStringKey(timer.name)
        }
    }
    
    var selectedCornerRadius: CGFloat {
        if #available(iOS 26, *) {
            return 24
        } else {
            return 8
        }
    }
    
    var progressBarColor: Color {
//        guard !isMinimized else { return Color.gustavLight }
//        guard !selected else { return Color.gustavLight }
        return isMainTimer ? Color.gustavLight : Color.gustavVolt
    }
    
    func getIntervalWidth(interval: IntervalData, viewWidth: CGFloat) -> CGFloat {
        let totalDuration = timer.intervals.reduce(0) { $0 + $1.value }
        let spacing = CGFloat(timer.intervals.count - 1) * 5
        return viewWidth * (CGFloat(interval.value) / CGFloat(totalDuration)) - (spacing / CGFloat(timer.intervals.count))
    }
}

#Preview {
    List {
        Section {
            FavouriteRowView(timer: {
                let timer = TimerData(order: 2, name: "My Favourite Timer", rounds: 5, selectedSound: .beep, isVibrating: true)
                timer.intervals = [
                    IntervalData(value: 30, name: "Work"),
                    IntervalData(value: 15, name: "Rest")
                ]
                return timer
            }(), selected: true)
            FavouriteRowView(timer: {
                let timer = TimerData(order: 2, name: "My Favourite Timer", rounds: 5, selectedSound: .whistle, isVibrating: true)
                timer.intervals = [
                    IntervalData(value: 30, name: "Work"),
                    IntervalData(value: 15, name: "Rest")
                ]
                return timer
            }(), selected: true, tip: "Box breathing, soustřeď se výhradně na dech (4-4-4-4: nádech, zadržení, výdech, zadržení). Kdykoli myšlenky odjedou jinam, jednoduše je vrátíš zpět k dechu.")
        }
        Section {
            FavouriteRowView(timer: {
                let timer = TimerData(order: 2, name: "My Favourite Timer", rounds: 5, selectedSound: .beep, isVibrating: true)
                timer.intervals = [
                    IntervalData(value: 30, name: "Work"),
                    IntervalData(value: 15, name: "Rest")
                ]
                return timer
            }(), selected: true, isMinimized: true)
            FavouriteRowView(timer: {
                let timer = TimerData(order: 2, name: "My Favourite Timer", rounds: 5, selectedSound: .whistle, isVibrating: true)
                timer.intervals = [
                    IntervalData(value: 30, name: "Work"),
                    IntervalData(value: 15, name: "Rest")
                ]
                return timer
            }(), selected: false, isMinimized: true)
        }
        FavouriteRowView(timer: {
            let timer = AppConfig.defaultTimer
            timer.order = 11
            timer.intervals = [
                IntervalData(value: 30, name: "Work"),
                IntervalData(value: 15, name: "Rest")
            ]
            return timer
        }(), selected: false)
    }
}
