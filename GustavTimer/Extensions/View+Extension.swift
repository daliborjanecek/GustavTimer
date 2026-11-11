//
//  HideKeyboardExtension.swift
//  GustavTimer
//
//  Created by Dalibor Janeček on 13.07.2024.
//

import Foundation
import SwiftUI

extension View {
    func saveTimerAlert(
        isPresented: Binding<Bool>,
        timerName: Binding<String>,
        onSave: @escaping () -> Void
    ) -> some View {
        self.alert("SAVE_TITLE", isPresented: isPresented) {
            TextField("TIMER_NAME_PROMPT", text: timerName)
            Button("SAVE") {
                onSave()
            }
            Button("CANCEL", role: .cancel) { }
        } message: {
            Text("SAVE_DIALOG")
        }
    }
}

extension View {
    /// Přejmenování uloženého oblíbeného.
    func renameTimerAlert(
        isPresented: Binding<Bool>,
        timerName: Binding<String>,
        onRename: @escaping () -> Void
    ) -> some View {
        self.alert("RENAME_FAVOURITE", isPresented: isPresented) {
            TextField("TIMER_NAME_PROMPT", text: timerName)
            Button("RENAME") {
                onRename()
            }
            Button("CANCEL", role: .cancel) { }
        }
    }
}
