//
//  TickingSettingsView.swift
//  GustavTimer
//
//  Created by Dalibor Janeček on 10.11.2026.
//

import SwiftUI
import GustavUICore

/// Podstránka nastavení s výběrem režimu tikání.
///
///     NavigationLink {
///         TickingSettingsView(ticking: setting(\.ticking, tracking: "ticking"))
///     } label: {
///         ListButton(name: "SET_TICKING", value: currentTimerData.ticking.title)
///     }
struct TickingSettingsView: View {
    @Binding var ticking: TickingMode

    var body: some View {
        List {
            SettingsSection {
                ForEach(TickingMode.allCases, id: \.self) { mode in
                    GustavSelectableListRow(selected: ticking == mode) {
                        Button {
                            select(mode)
                        } label: {
                            HStack {
                                Text(mode.title)
                                Spacer()
                            }
                        }
                    }
                }
            }
        }
        .font(.gustavBody)
        .toolbar { toolbar }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .title) {
            HStack {
                Text("SET_TICKING")
                    .font(.settingsNavbarTitle)
            }
            .padding(.vertical)
        }
    }

    /// Výběr režimu. Ukázkový tik, ať je slyšet, co se vybírá – stejně
    /// jako u zvuků.
    private func select(_ mode: TickingMode) {
        guard mode != ticking else { return }
        ticking = mode
        if mode != .off {
            SoundManager.instance.playTick()
        }
    }
}

extension TickingMode {
    /// Název režimu v nastavení.
    var title: LocalizedStringKey {
        switch self {
        case .off:          return "TICKING_OFF"
        case .everySecond:  return "TICKING_EVERY_SECOND"
        case .finalSeconds: return "TICKING_FINAL_SECONDS"
        }
    }
}

#Preview {
    NavigationStack {
        TickingSettingsView(ticking: .constant(.finalSeconds))
    }
}
