//
//  RoundsSettingsView.swift
//  GustavTimer
//
//  Created by Dalibor Janeček on 11.09.2025.
//

import SwiftUI
import GustavUICore

struct RoundsSettingsView: View {
    @Binding var rounds: Int
    /// Počet kol, na který se vrátí vypnutí smyčky.
    @State private var lastRoundOption: Int = AppConfig.roundsOptions.first ?? 1
        
    var body: some View {
        List {
            Section {
                Toggle(isOn: .init(get: {
                    rounds == -1
                }, set: { isLooping in
                    if isLooping {
                        // Zapamatovat i počet nastavený dřív, než se obrazovka
                        // otevřela – jinak by se vypnutí smyčky vracelo na 1.
                        if rounds != -1 { lastRoundOption = rounds }
                        rounds = -1
                    } else {
                        rounds = lastRoundOption
                    }
                })) {
                    Text("IS_LOOPING")
                        .font(.gustavBody)
                }
                .tint(Color.gustavVolt)
            }
            
            if rounds != -1 {
                Section {
                    ForEach(AppConfig.roundsOptions, id: \.self) { roundOption in
                        SelectableOptionRow(selected: rounds == roundOption) {
                            rounds = roundOption
                            lastRoundOption = roundOption
                        } label: {
                            Text("\(roundOption)")
                                .font(.bodyNumber)
                        }
                    }
                } header: {
                    Text("SELECT_ROUNDS_NUMBER")
                        .font(.sectionHeader)
                }
            }
        }
        .settingsTitle("ROUNDS")
    }
}

#Preview {
    @Previewable @State var rounds = 3
    NavigationStack {
        RoundsSettingsView(rounds: $rounds)
    }
}
