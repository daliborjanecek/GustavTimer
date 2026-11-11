//
//  HideKeyboardExtension.swift
//  GustavTimer
//
//  Created by Dalibor Janeček on 13.07.2024.
//

import Foundation
import SwiftUI

// MARK: - Titulek podstránky nastavení

extension View {
    /// Titulek podstránky nastavení ve fontu aplikace.
    ///
    ///     List { … }
    ///         .settingsTitle("ROUNDS")
    func settingsTitle(_ title: LocalizedStringKey) -> some View {
        toolbar {
            ToolbarItem(placement: .title) {
                Text(title)
                    .font(.settingsNavbarTitle)
                    .padding(.vertical)
            }
        }
    }
}

// MARK: - Dialogy s názvem timeru

extension View {
    /// Uložení aktivního timeru do oblíbených.
    func saveTimerAlert(
        isPresented: Binding<Bool>,
        timerName: Binding<String>,
        onSave: @escaping () -> Void
    ) -> some View {
        timerNameAlert(
            "SAVE_TITLE", message: "SAVE_DIALOG", confirm: "SAVE",
            isPresented: isPresented, timerName: timerName, onConfirm: onSave
        )
    }

    /// Přejmenování uloženého oblíbeného.
    func renameTimerAlert(
        isPresented: Binding<Bool>,
        timerName: Binding<String>,
        onRename: @escaping () -> Void
    ) -> some View {
        timerNameAlert(
            "RENAME_FAVOURITE", confirm: "RENAME",
            isPresented: isPresented, timerName: timerName, onConfirm: onRename
        )
    }

    /// Dialog s polem pro název timeru – společný základ obou dialogů výše.
    private func timerNameAlert(
        _ title: LocalizedStringKey,
        message: LocalizedStringKey? = nil,
        confirm: LocalizedStringKey,
        isPresented: Binding<Bool>,
        timerName: Binding<String>,
        onConfirm: @escaping () -> Void
    ) -> some View {
        alert(title, isPresented: isPresented) {
            TextField("TIMER_NAME_PROMPT", text: timerName)
            Button(confirm, action: onConfirm)
            Button("CANCEL", role: .cancel) { }
        } message: {
            if let message {
                Text(message)
            }
        }
    }
}
