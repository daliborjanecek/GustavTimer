//
//  FavouritesItemView.swift
//  GustavTimer
//
//  Created by Dalibor Janeček on 06.09.2025.
//

import SwiftUI
import GustavUICore

struct FavouriteRowView: View {

    /// Nastavení zobrazovaného timeru. Hodnotový typ, takže řádek umí vykreslit
    /// uložený oblíbený (`TimerData.settings`) i předdefinovaný preset,
    /// který v databázi vůbec není.
    let settings: TimerSettings
    let selected: Bool

    /// Vykreslí řádek jako „aktuální timer“ – ztlumený název místo vlastního
    /// a světlý progress bar. `order` součástí nastavení není, proto se to
    /// předává zvlášť. Dnes to nikdo nenastavuje na `true`; řádek se používá
    /// jen pro oblíbené a presety.
    var isMainTimer: Bool = false
    var isMinimized: Bool = false
    var tip: String? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            GustavSelectableListRow(selected: selected) {
                    VStack(alignment: .leading, spacing: isMinimized ? 4 : 36) {
                        if !isMinimized {
                            GeometryReader { geometry in
                                HStack(alignment: .top, spacing: 5) {
                                    ForEach(settings.intervals) { interval in
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
                                if settings.rounds == -1 {
                                    GustavIcon(.loop, size: 22, color: Color.gustavLight)
                                }
                                
                                if settings.sound != nil {
                                    GustavIcon(.sound, size: 22, color: Color.gustavLight)
                                }
                                
                                if settings.isVibrating {
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
            return LocalizedStringKey(settings.name)
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
        let totalDuration = settings.intervals.reduce(0) { $0 + $1.value }
        let spacing = CGFloat(settings.intervals.count - 1) * 5
        return viewWidth * (CGFloat(interval.value) / CGFloat(totalDuration)) - (spacing / CGFloat(settings.intervals.count))
    }
}

#Preview {
    let workRest = [
        IntervalData(value: 30, name: "Work"),
        IntervalData(value: 15, name: "Rest")
    ]
    let beepTimer = TimerSettings(
        name: "My Favourite Timer", intervals: workRest, rounds: 5,
        sound: .beep, isVibrating: true, isTicking: false, hasCountdown: true
    )
    let whistleTimer = TimerSettings(
        name: "My Favourite Timer", intervals: workRest, rounds: 5,
        sound: .whistle, isVibrating: true, isTicking: false, hasCountdown: true
    )

    List {
        Section {
            FavouriteRowView(settings: beepTimer, selected: true)
            FavouriteRowView(settings: whistleTimer, selected: true, tip: "Box breathing, soustřeď se výhradně na dech (4-4-4-4: nádech, zadržení, výdech, zadržení). Kdykoli myšlenky odjedou jinam, jednoduše je vrátíš zpět k dechu.")
        }
        Section {
            FavouriteRowView(settings: beepTimer, selected: true, isMinimized: true)
            FavouriteRowView(settings: whistleTimer, selected: false, isMinimized: true)
        }
        FavouriteRowView(settings: AppConfig.defaultTimer, selected: false, isMainTimer: true)
    }
}
