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
    
    var count: String {
        viewModel.formattedCurrentTime(timeDisplayFormat: .seconds)
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(count)
                .contentTransition(.numericText())
                .font(Font.custom("MartianMono-Bold", size: 300))
                .minimumScaleFactor(0.01)
                .foregroundStyle(Color.gustavVolt)
                .onTapGesture {
                    viewModel.startStopTimer()
                }
                .animation(isLuminanceReduced ? nil : .easeInOut(duration: 0.2), value: count)
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

#Preview {
    NavigationStack {
        TabView {
            TimerView(viewModel: .init())
        }
        .tabViewStyle(.verticalPage)
    }
}
