//
//  TickingSettingsView.swift
//  GustavTimer
//
//  Created by Dalibor Janeček on 10.11.2026.
//

import SwiftUI
import GustavUICore

/// Podstránka nastavení tikání: nahoře přepínač zapnuto/vypnuto, pod ním
/// (jen při zapnutém tikání) výběr, kdy se tikne – stejně jako u zvuků
/// a opakování.
///
///     NavigationLink {
///         TickingSettingsView(ticking: setting(\.ticking, tracking: "ticking"))
///     } label: {
///         ListButton(name: "SET_TICKING", value: currentTimerData.ticking.title)
///     }
struct TickingSettingsView: View {
    @Binding var ticking: TickingMode

    /// Režim, na který se vrátí zapnutí přepínače. Dřívější „zapnuto“
    /// tikalo každou sekundu, proto je to výchozí hodnota.
    @State private var lastMode: TickingMode

    init(ticking: Binding<TickingMode>) {
        _ticking = ticking
        _lastMode = State(initialValue: ticking.wrappedValue == .off ? .everySecond : ticking.wrappedValue)
    }

    var body: some View {
        List {
            SettingsSection {
                Toggle(isOn: .init(get: {
                    ticking != .off
                }, set: { isOn in
                    if isOn {
                        ticking = lastMode
                    } else {
                        if ticking != .off { lastMode = ticking }
                        ticking = .off
                    }
                })) {
                    Text("SET_TICKING")
                }
                .tint(Color.gustavVolt)
            }

            if ticking != .off {
                SettingsSection(label: "SELECT_TICKING") {
                    ForEach(TickingMode.allCases.filter { $0 != .off }, id: \.self) { mode in
                        SelectableOptionRow(selected: ticking == mode) {
                            select(mode)
                        } label: {
                            Text(mode.title)
                        }
                    }
                }
            }
        }
        .font(.gustavBody)
        .settingsTitle("SET_TICKING")
    }

    /// Výběr režimu. Ukázkový tik, ať je slyšet, co se vybírá – stejně
    /// jako u zvuků.
    private func select(_ mode: TickingMode) {
        guard mode != ticking else { return }
        ticking = mode
        lastMode = mode
        SoundManager.instance.playTick()
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
    @Previewable @State var ticking = TickingMode.finalSeconds
    NavigationStack {
        TickingSettingsView(ticking: $ticking)
    }
}

#Preview("Vypnuto") {
    @Previewable @State var ticking = TickingMode.off
    NavigationStack {
        TickingSettingsView(ticking: $ticking)
    }
}
