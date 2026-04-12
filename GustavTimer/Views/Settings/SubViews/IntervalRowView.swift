//
//  IntervalRowView.swift
//  GustavTimer
//
//  Created by Dalibor Janeček on 16.09.2025.
//

import SwiftUI
import GustavUICore

struct IntervalRowView: View {
    @Binding var intervalName: String
    @Binding var intervalValue: Int

    @FocusState private var focusedField: Field?
    @State private var valueText: String = ""

    private enum Field: Int, CaseIterable {
        case name, value
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("INTERVAL")
                        .font(.settingsCaption)
                        .foregroundStyle(Color.gustavLight)
                    TextField("INTERVAL_NAME_PROMPT", text: $intervalName)
                        .font(.settingsIntervalName)
                        .focused($focusedField, equals: .name)
                        .submitLabel(.done)
                }

                VStack(alignment: .trailing, spacing: 4) {
                    Text("INTERVAL_VALUE")
                        .font(.settingsCaption)
                        .foregroundStyle(Color.gustavLight)
                    TextField("1-\(AppConfig.maxTimerValue)", text: $valueText)
                        .keyboardType(.numberPad)
                        .font(.settingsIntervalValue)
                        .multilineTextAlignment(.trailing)
                        .focused($focusedField, equals: .value)
                        .submitLabel(.done)
                        .onChange(of: valueText) { newValue in
                            let filtered = newValue.filter { $0.isNumber }
                            if filtered != newValue {
                                valueText = filtered
                            }
                        }
                        .onSubmit {
                            commitValue()
                        }
                }
                .frame(maxWidth: 120)
            }
        }
        .onAppear {
            valueText = "\(intervalValue)"
        }
        .onChange(of: intervalValue) { newValue in
            if focusedField != .value {
                valueText = "\(newValue)"
            }
        }
        .onChange(of: focusedField) { newFocus in
            if newFocus != .value {
                commitValue()
            }
        }
    }

    private func commitValue() {
        if let parsed = Int(valueText) {
            let clamped = min(max(parsed, 1), AppConfig.maxTimerValue)
            intervalValue = clamped
            valueText = "\(clamped)"
        } else {
            valueText = "\(intervalValue)"
        }
    }
}
