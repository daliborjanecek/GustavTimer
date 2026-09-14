//
//  SoundView.swift
//  GustavTimer
//
//  Created by Dalibor Janeček on 05.09.2024.
//

import SwiftUI
import GustavUICore
import TelemetryDeck

struct SoundSettingsView: View {
    
    @Binding var selectedSound: SoundModel?

    /// Zvuk, na který se má vrátit přepínač ztlumení. Nastavení zařízení –
    /// jako `@State` se ztrácel při každém odchodu z obrazovky.
    @AppStorage(AppPreferences.Key.lastSelectedSound) private var lastSelectedSound: SoundModel = .beep
    
    var body: some View {
        List {
            SettingsSection {
                Toggle(isOn: .init(get: {
                    selectedSound != nil
                }, set: { bool in
                    if bool {
                        selectedSound = lastSelectedSound
                    } else {
                        if let current = selectedSound { lastSelectedSound = current }
                        selectedSound = nil
                    }
                })) {
                    Text("IS_SOUND_ENABLED")
                }
                .tint(Color.gustavVolt)
            }
            
            if selectedSound != nil {
                SettingsSection(label: "SELECT_SOUND") {
                    ForEach(AppConfig.soundThemes, id: \.id) { soundTheme in
                        GustavSelectableListRow(selected: selectedSound == soundTheme) {
                            Button {
                                setSelectedSound(soundTheme)
                                SoundManager.instance.playSound(soundModel: soundTheme)
                            } label: {
                                HStack {
                                    Text(soundTheme.title)
                                    Spacer()
                                }
                            }
                        }
                    }
                }
            }
        }
//        .animation(.easeInOut, value: selectedSound)
        .font(.gustavBody)
        .toolbar{toolbar}
    }
    
    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        if #available(iOS 26, *){
            ToolbarItem(placement: .title) {
                HStack {
                    Text("SOUND")
                        .font(.settingsNavbarTitle)
                }
                .padding(.vertical)
            }
        } else {
            // Fallback to earlier versions
            ToolbarItem(placement: .title) {
                HStack {
                    Text("SOUND")
                        .font(.settingsNavbarTitle)
                }
                .padding(.vertical)
            }
        }
    }
    
    func setSelectedSound(_ sound: SoundModel) {
        self.selectedSound = sound
        self.lastSelectedSound = sound

        TelemetryDeck.signal(
            "timer.sound_selected",
            parameters: [
                "sound": sound.rawValue
            ]
        )
    }
}

#Preview {
    SoundSettingsView(selectedSound: .constant(AppConfig.soundThemes.first!))
}
