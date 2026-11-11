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
                        GustavSelectableListRow(selected: rounds == roundOption) {
                            Button {
                                rounds = roundOption
                                lastRoundOption = roundOption
                            } label: {
                                HStack {
                                    Text("\(roundOption)")
                                        .font(.bodyNumber)
                                    Spacer()
                                }
                            }
                        }
                    }
                } header: {
                    Text("SELECT_ROUNDS_NUMBER")
                        .font(.sectionHeader)
                }
            }
        }
        .toolbar{toolbar}
    }
    
    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        if #available(iOS 26, *){
            ToolbarItem(placement: .title) {
                HStack {
                    Text("ROUNDS")
                        .font(.settingsNavbarTitle)
                }
                .padding(.vertical)
            }
        } else {
            // Fallback to earlier versions
            ToolbarItem(placement: .title) {
                HStack {
                    Text("ROUNDS")
                        .font(.settingsNavbarTitle)
                }
                .padding(.vertical)
            }
        }
    }
}

#Preview {
    RoundsSettingsView(rounds: .constant(3))
}
