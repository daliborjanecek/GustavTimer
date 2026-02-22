//
//  ContentView.swift
//  Gustav Timer Watch Watch App
//
//  Created by Dalibor Janeček on 21.02.2026.
//

import SwiftUI
import GustavUICore

struct ContentView: View {
    @StateObject var viewModel = TimerViewModel()
    @StateObject var workoutManager = WorkoutManager()
    @State var selectedPage: Int = 0
    
    @State var firstInterval: Int = 60
    @State var secondInterval: Int = 30
    @State private var firstIntervalDouble: Double = 60
    @State private var secondIntervalDouble: Double = 30
    
    @Namespace var bookIcon
    @Namespace var library
    
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    var body: some View {
        TabView(selection: $selectedPage) {
            NavigationStack {
                Text("\(viewModel.count)")
                    .contentTransition(.numericText())
                    .font(Font.custom("MartianMono-Bold", size: 200))
                    .minimumScaleFactor(0.01)
                    .foregroundStyle(Color.gustavVolt)
                    .onTapGesture {
                        viewModel.startStopTimer()
                    }
                    .animation(isLuminanceReduced ? .none : .bouncy, value: viewModel.count)
                    .matchedGeometryEffect(
                                        id: bookIcon,
                                        in: library,
                                        properties: [.size, .position],
                                        isSource: selectedPage == 0)
                    .navigationTitle("Timer")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tag(0)
            
            NavigationStack {
                VStack {
                    HStack {
                        Text("\(viewModel.count)")
                            .font(Font.custom("MartianMono-Bold", size: 20))
                            .minimumScaleFactor(0.01)
                            .foregroundStyle(Color.gustavVolt)
                            .matchedGeometryEffect(
                                                id: bookIcon,
                                                in: library,
                                                properties: [.position, .size],
                                                isSource: selectedPage == 1)
                            .padding(.horizontal)
                        Spacer()
                    }
                    Spacer()
                    Button {
                        viewModel.startStopTimer()
                    } label: {
                        Text(viewModel.isTimerRunning ? "Stop" : "Start")
                            .font(.gustavBody)
                    }
                    Button {
                        viewModel.resetTimer()
                    } label: {
                        Text("reset")
                            .font(.gustavBody)
                    }
                }
                .navigationTitle("Controls")
                .navigationBarTitleDisplayMode(.inline)
            }
            .tag(1)
            
            NavigationStack {
                VStack {
                    Text("First interval: \(firstInterval)s")
                        .font(.gustavBody)
                    Slider(value: $firstIntervalDouble, in: 1...300, step: 1) { _ in
                        firstInterval = Int(firstIntervalDouble)
                    }
                    .onChange(of: firstIntervalDouble) { _, newValue in
                        firstInterval = Int(newValue)
                    }
                    
                }
                .navigationTitle("Edit")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
        .tabViewStyle(.verticalPage)
    }
}

#Preview {
    ContentView()
}
