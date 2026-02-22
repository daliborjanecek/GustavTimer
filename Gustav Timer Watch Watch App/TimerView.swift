//
//  TimerView.swift
//  Gustav Timer Watch Watch App
//
//  Created by Dalibor Janeček on 21.02.2026.
//

import SwiftUI
import GustavUICore

struct TimerView: View {
    
    @ObservedObject var viewModel: TimerViewModel
    @Namespace var bookIcon
    @Namespace var library
    
    var body: some View {
        NavigationStack {
            Text("\(viewModel.count)")
                .contentTransition(.numericText())
                .font(.timerCounter)
                .minimumScaleFactor(0.01)
                .foregroundStyle(Color.gustavVolt)
                .onTapGesture {
                    viewModel.startStopTimer()
                }
                .animation(.easeInOut, value: viewModel.count)
                .matchedGeometryEffect(
                                    id: bookIcon,
                                    in: library,
                                    properties:  .frame,
                                    isSource: true)
//                .toolbar {
//                    ToolbarItem(placement: .topBarLeading) {
//                        Button {
//                            // Perform an action here.
//                        } label: {
//                            Image(systemName:"suit.heart")
//                        }
//                    }
//                    
//                }
        }
    }
}
