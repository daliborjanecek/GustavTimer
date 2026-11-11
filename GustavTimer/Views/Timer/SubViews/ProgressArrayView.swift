//
//  ProgressArrayView.swift
//  GustavTimer
//
//  Created by Dalibor Janeček on 01.10.2023.
//

import SwiftUI

/// Řada ukazatelů průběhu – jeden na interval, široký podle jeho délky.
/// Hotové intervaly jsou plné, aktivní ukazuje `progress`, další jsou prázdné.
///
///     ProgressArrayView(
///         intervals: viewModel.timers,
///         activeIndex: viewModel.activeTimerIndex,
///         progress: viewModel.progress
///     )
struct ProgressArrayView: View {
    let intervals: [IntervalData]
    let activeIndex: Int
    /// Průběh aktivního intervalu, 0–1.
    let progress: Double

    private let spacing: CGFloat = 5

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: spacing) {
                ForEach(Array(intervals.enumerated()), id: \.offset) { index, interval in
                    ProgressBar(progress: progress(ofIntervalAt: index))
                        .frame(width: width(of: interval, in: geometry.size.width))
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                }
            }
        }
        .padding(.horizontal)
        .frame(height: 6)
    }

    private func progress(ofIntervalAt index: Int) -> Double {
        if index == activeIndex { return progress }
        return index < activeIndex ? 1 : 0
    }

    /// Šířka podle podílu intervalu na délce celého kola.
    private func width(of interval: IntervalData, in totalWidth: CGFloat) -> CGFloat {
        let total = intervals.reduce(0) { $0 + $1.value }
        guard total > 0 else { return 0 }
        let available = totalWidth - CGFloat(intervals.count - 1) * spacing
        return max(0, available * CGFloat(interval.value) / CGFloat(total))
    }
}

#Preview {
    ProgressArrayView(
        intervals: [
            IntervalData(value: 30, name: "Work"),
            IntervalData(value: 15, name: "Rest"),
            IntervalData(value: 45, name: "Work")
        ],
        activeIndex: 1,
        progress: 0.6
    )
    .padding(.vertical)
    .background(.black)
}
