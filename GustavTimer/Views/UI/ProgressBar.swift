//
//  ProgressBarView.swift
//  GustavTimer
//
//  Created by Dalibor Janeček on 11.09.2023.
//

import SwiftUI
import GustavUICore

struct ProgressBar: View {
    @Binding var progress: Double
    
    var cornerRadius: CGFloat = 0
    
    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Color.gustavNeutral
                    .cornerRadius(cornerRadius)
                    .clipShape(Capsule())
                Color.gustavVolt
                    .frame(width: proxy.size.width * progress)
                    .cornerRadius(cornerRadius)
                    .clipShape(Capsule())
            }
        }
    }
}
