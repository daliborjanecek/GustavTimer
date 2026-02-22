//
//  SettingsSection.swift
//  GustavTimer
//
//  Created by Dalibor Janeček on 11.11.2025.
//

import SwiftUI
import GustavUICore

struct SettingsSection<Content: View>: View {
    var label: LocalizedStringKey? = nil
    var footer: LocalizedStringKey? = nil
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        if let label, let footer {
            Section(header: Text(label)
                .font(.sectionHeader)
                .foregroundStyle(Color.gustavNeutral),
                    footer: Text(footer)
                .font(.sectionFooter)
                .foregroundStyle(Color.gustavNeutral)) {
                    content()
                }
        } else if let label {
            Section(header: Text(label)
                .font(.sectionHeader)
                .foregroundStyle(Color.gustavNeutral)) {
                    content()
                }
        } else {
            Section {
                content()
            }
        }
    }
}
