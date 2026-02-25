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

    var body: some View {
        VStack {
            // Zobrazení hodnot
            HStack(alignment: .bottom, spacing: 0) {
                let fontSize: CGFloat = 32
                    Text("\(Int(firstInterval))")
                        .font(Font.custom("MartianMono-Bold", size: fontSize))
                        .foregroundColor(editingFirst ? .gustavVolt : .gustavNeutral)
                .onTapGesture { editingFirst = true }

                Text("/")
                    .font(Font.custom("MartianMono-Bold", size: fontSize))
                    .foregroundStyle(Color.gustavNeutral)
                
                    Text("\(Int(secondInterval))")
                        .font(Font.custom("MartianMono-Bold", size: fontSize))
                        .foregroundColor(!editingFirst ? .gustavVolt : .gustavNeutral)
                .onTapGesture { editingFirst = false }
            }
            .padding()

            Spacer()

            Button {
                viewModel.loadSimpleTimer(Int(firstInterval), Int(secondInterval))
                onDone()
            } label: {
                Text("Save")
            }
        }
        .onAppear {
            // Načti uložené hodnoty při prvním zobrazení
            if viewModel.timers.count >= 2 {
                firstInterval = Double(viewModel.timers[0].value)
                secondInterval = Double(viewModel.timers[1].value)
            }
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
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Text("Edit")
                    .font(.gustavBody)
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel.loadSimpleTimer(Int(firstInterval), Int(secondInterval))
                    onDone()
                } label: {
                    Text("Save")
                }
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
