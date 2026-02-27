//
//  TimerView.swift
//  Gustav Timer Watch Watch App
//
//  Created by Dalibor Janeček on 21.02.2026.
//

import SwiftUI
import GustavUICore

struct TimerView: View {

    @ObservedObject var viewModel: TimerViewModel
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    var body: some View {
        TimelineView(TimerTimelineSchedule(from: .now, isPaused: !viewModel.isTimerRunning)) { context in
            let count = viewModel.count(at: context.date)
            VStack(spacing: 0) {
                Text("\(count)")
                    .contentTransition(.numericText())
                    .font(Font.custom("MartianMono-Bold", size: 300))
                    .minimumScaleFactor(0.01)
                    .foregroundStyle(Color.gustavVolt)
                    .onTapGesture {
                        viewModel.startStopTimer()
                    }
                    .animation(isLuminanceReduced ? nil : .easeInOut(duration: 0.2), value: count)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                ZStack {
                    Circle()
                        .fill(Color.gustavVolt.opacity(0.3))
                        .frame(width: 30, height: 30)

                    Circle()
                        .trim(from: 0, to: viewModel.progress)
                        .stroke(
                            Color.gustavVolt,
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .frame(width: 30, height: 30)
                        .rotationEffect(.degrees(-90)) // Start z 12 hodin
                        .animation(.linear(duration: 1), value: viewModel.progress)

                    if let firstLetter = viewModel.activeIntervalName.first {
                        Text(String(firstLetter))
                            .font(.bodyNumber)
                            .foregroundStyle(Color.gustavVolt)
                    }
                }
            }
        }
    }
}

/// Custom TimelineSchedule podle WWDC21 vzoru (Build a workout app for Apple Watch).
/// V normálním režimu aktualizuje 30x/sec (plynulé setiny),
/// v lowFrequency (AOD) aktualizuje 1x/sec.
struct TimerTimelineSchedule: TimelineSchedule {
    var startDate: Date
    var isPaused: Bool

    init(from startDate: Date, isPaused: Bool = false) {
        self.startDate = startDate
        self.isPaused = isPaused
    }

    func entries(from startDate: Date, mode: TimelineScheduleMode) -> AnyIterator<Date> {
        guard !isPaused else {
            return AnyIterator { nil }
        }
        let interval: TimeInterval = mode == .lowFrequency ? 1.0 : 1.0 / 30.0
        var current = startDate
        return AnyIterator {
            let next = current
            current = current.addingTimeInterval(interval)
            return next
        }
    }
}

#Preview {
    NavigationStack {
        TabView {
            TimerView(viewModel: .init())
        }
        .tabViewStyle(.verticalPage)
    }
}
