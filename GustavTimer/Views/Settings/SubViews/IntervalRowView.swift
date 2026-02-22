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
                        .onSubmit {
                            //
                        }
                        .submitLabel(.done)
                }
                
//                Spacer(minLength: 50)
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("INTERVAL_VALUE")
                        .font(.settingsCaption)
                        .foregroundStyle(Color.gustavLight)
                    TextField("1-\(AppConfig.maxTimerValue)", value: $intervalValue, format: .number)
                        .keyboardType(.numberPad)
                        .font(.settingsIntervalValue)
                        .multilineTextAlignment(.trailing)
                        .focused($focusedField, equals: .value)
                        .onSubmit {
                            //
                        }
                        .submitLabel(.done)
                }
                .frame(maxWidth: 120)
            }
//            if focusedField != nil {
//                GustavSmallPillButton(label: "DONE", color: Color.gustavLight) {
//                    focusedField = nil
//                }
//            }
        }
    }
}
