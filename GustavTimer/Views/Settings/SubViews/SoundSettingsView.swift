//
//  SoundView.swift
//  GustavTimer
//
//  Created by Dalibor Janeček on 05.09.2024.
//

import SwiftUI
import GustavUICore

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
                    Analytics.settingChanged("sound_enabled", value: bool)
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
                        SelectableOptionRow(selected: selectedSound == soundTheme) {
                            setSelectedSound(soundTheme)
                            SoundManager.instance.playSound(soundModel: soundTheme)
                        } label: {
                            Text(soundTheme.title)
                        }
                    }
                }
            }
        }
        .font(.gustavBody)
        .settingsTitle("SOUND")
    }
    
    func setSelectedSound(_ sound: SoundModel) {
        self.selectedSound = sound
        self.lastSelectedSound = sound

        Analytics.send(.soundSelected, parameters: ["sound": sound.rawValue])
    }
}

#Preview {
    SoundSettingsView(selectedSound: .constant(AppConfig.soundThemes.first!))
}
