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
        VStack {
            Text(viewModel.formattedCurrentTime(timeDisplayFormat: isLuminanceReduced ? .seconds : .minutesSecondsHundredths))
                .font(Font.custom("MartianMono-Bold", size: 30))
                .foregroundStyle(Color.gustavVolt)
                .onTapGesture {
                    viewModel.startStopTimer()
                }
            Spacer()
            HStack {
                Button {
                    viewModel.startStopTimer()
                } label: {
                    GustavIcon(viewModel.isTimerRunning ? .pause : .play, size: 42, color: viewModel.isTimerRunning ? .gustavPink : .gustavVolt)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .clipShape(Circle())
                .buttonStyle(.bordered)
                .tint(viewModel.isTimerRunning ? .gustavPink : .gustavVolt)
                
                
                Button {
                    if viewModel.isTimerRunning {
                        viewModel.skipInterval()
                    } else {
                        viewModel.resetTimer()
                    }
                } label: {
                    GustavIcon(viewModel.isTimerRunning ? .skip : .reset, size: 42)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .clipShape(Circle())
                .buttonStyle(.bordered)
                .tint(.white)
            }
        }
        .ignoresSafeArea(edges: .bottom)
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
