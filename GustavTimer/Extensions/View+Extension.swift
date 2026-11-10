//
//  HideKeyboardExtension.swift
//  GustavTimer
//
//  Created by Dalibor Janeček on 13.07.2024.
//

import Foundation
import SwiftUI

extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

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
    func alreadySavedAlert(
        isPresented: Binding<Bool>
    ) -> some View {
        self.alert("ALREADY_SAVED_TITLE", isPresented: isPresented) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("ALREADY_SAVED_DIALOG")
        }
    }
}
