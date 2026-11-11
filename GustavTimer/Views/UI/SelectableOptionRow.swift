//
//  SelectableOptionRow.swift
//  GustavTimer
//
//  Created by Dalibor Janeček on 11.11.2026.
//

import SwiftUI
import GustavUICore

/// Řádek seznamu, ze kterého se vybírá jedna možnost – kola, zvuk, tikání.
/// Klepnout jde na celou šířku řádku, vybraný řádek je zvýrazněný.
///
///     ForEach(TickingMode.allCases, id: \.self) { mode in
///         SelectableOptionRow(selected: ticking == mode) {
///             ticking = mode
///         } label: {
///             Text(mode.title)
///         }
///     }
struct SelectableOptionRow<Label: View>: View {
    let selected: Bool
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    var body: some View {
        GustavSelectableListRow(selected: selected) {
            Button(action: action) {
                HStack {
                    label()
                    Spacer()
                }
            }
        }
    }
}

#Preview {
    List {
        SelectableOptionRow(selected: true, action: {}) {
            Text(verbatim: "Vybraná možnost")
        }
        SelectableOptionRow(selected: false, action: {}) {
            Text(verbatim: "Jiná možnost")
        }
    }
    .font(.gustavBody)
}
