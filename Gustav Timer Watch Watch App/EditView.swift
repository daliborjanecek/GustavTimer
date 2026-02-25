//
//  EditView.swift
//  GustavTimer
//
//  Created by Dalibor Janeček on 25.02.2026.
//

import SwiftUI
import GustavUICore

struct EditView: View {

    @ObservedObject var viewModel: TimerViewModel
    let onDone: () -> Void

    @State private var firstInterval: Double = 60
    @State private var secondInterval: Double = 30
    @State private var editingFirst = true
    @State private var fontSize: CGFloat = 32

    var body: some View {
        VStack {
            // Zobrazení hodnot
            HStack(alignment: .bottom, spacing: 4) {
                VStack {
                    Text("Work")
                        .font(.gustavBody)
                    Text("\(Int(firstInterval))")
                        .font(Font.custom("MartianMono-Bold", size: fontSize))
                        
                }
                .foregroundColor(editingFirst ? .gustavVolt : .gustavNeutral)
                .onTapGesture { editingFirst = true }

                Text("/")
                    .font(Font.custom("MartianMono-Bold", size: fontSize))
                    .foregroundColor(.gustavNeutral)
                
                VStack {
                    Text("Rest")
                        .font(.gustavBody)
                    Text("\(Int(secondInterval))")
                        .font(Font.custom("MartianMono-Bold", size: fontSize))
                        
                }
                .foregroundColor(!editingFirst ? .gustavVolt : .gustavNeutral)
                .onTapGesture { editingFirst = false }

            }
        }
        .onAppear {
            // Načti uložené hodnoty při prvním zobrazení
            if viewModel.timers.count >= 2 {
                firstInterval = Double(viewModel.timers[0].value)
                secondInterval = Double(viewModel.timers[1].value)
            }
            adjustFontSize()
        }
        .focusable(true)
        .digitalCrownRotation(
            editingFirst ? $firstInterval : $secondInterval,
            from: 1,
            through: 300,
            by: 1,
            sensitivity: .medium,
            isContinuous: false,
            isHapticFeedbackEnabled: true
        )
        .onChange(of: firstInterval) { oldValue, newValue in
            adjustFontSize()
        }
        .onChange(of: secondInterval) {
            adjustFontSize()
        }
        .toolbar {
            ToolbarItem(placement: .bottomBar) {
                Button {
                    viewModel.loadSimpleTimer(Int(firstInterval), Int(secondInterval))
                    onDone()
                } label: {
                    GustavIcon(.done, color: .gustavVolt)
                }
                .clipShape(Circle())
                .buttonStyle(.glass)
                .tint(.gustavVolt)

            }
        }
    }
    
    func adjustFontSize() {
        if firstInterval > 99 || secondInterval > 99 {
            withAnimation {
                fontSize = 32
            }
        } else {
            withAnimation {
                fontSize = 40
            }
        }
    }
}

#Preview {
    NavigationStack {
        TabView {
            EditView(viewModel: .init()) {
                //
            }
        }
        .tabViewStyle(.verticalPage)
    }
}
