//
//  SettingsSection.swift
//  GustavTimer
//
//  Created by Dalibor Janeček on 11.11.2025.
//

import SwiftUI
import GustavUICore

/// Sekce v nastavení s volitelným nadpisem a patičkou v jednotném stylu.
///
///     SettingsSection(label: "FEEDBACK", footer: "FEEDBACK_DESCRIPTION") {
///         Toggle("HAPTICS", isOn: $isVibrating)
///     }
struct SettingsSection<Content: View>: View {
    var label: LocalizedStringKey? = nil
    var footer: LocalizedStringKey? = nil
    @ViewBuilder let content: () -> Content

    var body: some View {
        Section {
            content()
        } header: {
            if let label {
                Text(label)
                    .font(.sectionHeader)
                    .foregroundStyle(Color.gustavNeutral)
            }
        } footer: {
            if let footer {
                Text(footer)
                    .font(.sectionFooter)
                    .foregroundStyle(Color.gustavNeutral)
            }
        }
    }
}
