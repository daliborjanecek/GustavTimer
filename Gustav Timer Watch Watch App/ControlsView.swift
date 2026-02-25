//
//  ControlsView.swift
//  GustavTimer
//
//  Created by Dalibor Janeček on 25.02.2026.
//

import SwiftUI
import GustavUICore

struct ControlsView: View {
    @ObservedObject var viewModel: TimerViewModel
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(viewModel.formattedCurrentTime(timeDisplayFormat: isLuminanceReduced ? .seconds : .secondsHundredths))
                .font(Font.custom("MartianMono-Bold", size: 300))
                .minimumScaleFactor(0.01)
                .foregroundStyle(Color.gustavVolt)
                .onTapGesture {
                    viewModel.startStopTimer()
                }
            Text(viewModel.activeIntervalName)
                .font(.gustavBody)
                .foregroundStyle(Color.gustavVolt)
        }
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                Button {
                    viewModel.startStopTimer()
                } label: {
                    GustavIcon(viewModel.isTimerRunning ? .pause : .play, color: viewModel.isTimerRunning ? .gustavPink : .gustavVolt)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .clipShape(Circle())
                .buttonStyle(.glass)
                .tint(viewModel.isTimerRunning ? .gustavPink : .gustavVolt)
                
                Button {
                    if viewModel.isTimerRunning {
                        viewModel.skipInterval()
                    } else {
                        viewModel.resetTimer()
                    }
                } label: {
                    GustavIcon(viewModel.isTimerRunning ? .skip : .reset)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .clipShape(Circle())
                .buttonStyle(.glass)
                .tint(.white)
            }
        }
    }
}

#Preview {
    NavigationStack {
        TabView {
            ControlsView(viewModel: .init())
        }
        .tabViewStyle(.verticalPage)
    }
}
