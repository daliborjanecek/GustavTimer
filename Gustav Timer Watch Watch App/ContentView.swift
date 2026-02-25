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
    @State var selectedPage: Int = 0
    
    var body: some View {
        NavigationStack {
            TabView(selection: $selectedPage) {
                TimerView(viewModel: viewModel).tag(0)
                ControlsView(viewModel: viewModel).tag(1)
                EditView(viewModel: viewModel, onDone: {
                    selectedPage = 0
                }).tag(2)
            }
            .tabViewStyle(.verticalPage)
        }
    }
}

#Preview {
    ContentView()
}
