//
//  EditView.swift
//  GustavTimer
//
//  Created by Dalibor Janeček on 25.02.2026.
//

import SwiftUI
import GustavUICore

struct EditView: View {
    
    @ObservedObject var viewModel: TimerViewModel
    let onDone: () -> Void
    
    @State private var firstInterval: Int = 60
    @State private var secondInterval: Int = 30
    
    @FocusState private var focusedPicker: Int?
    
    var body: some View {
        VStack {
            HStack(spacing: 16) {
                Picker(selection: $firstInterval) {
                    ForEach(1...300, id: \.self) {
                        Text("\($0)")
                            .font(Font.custom("MartianMono-Bold", size: 30))
                    }
                } label: {
                    Text("Work")
                        .font(.gustavBody)
                }
                .tint(.gustavVolt)
                .tag(4)
                .focused($focusedPicker, equals: 4)
                
                Picker(selection: $secondInterval) {
                    ForEach(1...300, id: \.self) {
                        Text("\($0)")
                            .font(Font.custom("MartianMono-Bold", size: 30))
                    }
                } label: {
                    Text("Rest")
                        .font(.gustavBody)
                }
                .tint(.gustavVolt)
                .tag(5)
                .focused($focusedPicker, equals: 5)
            }
            .padding()
            
            Spacer ()
            Button {
                viewModel.loadSimpleTimer(firstInterval, secondInterval)
                onDone()
            } label: {
                Text("Save")
            }

        }
        
    }
}

#Preview {
    NavigationStack {
        TabView {
            EditView(viewModel: .init()) {
                //
            }
        }
        .tabViewStyle(.verticalPage)
    }
}
