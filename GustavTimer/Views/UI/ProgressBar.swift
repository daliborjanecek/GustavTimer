//
//  ProgressBarView.swift
//  GustavTimer
//
//  Created by Dalibor Janeček on 11.09.2023.
//

import SwiftUI
import GustavUICore

/// Vodorovný ukazatel průběhu.
///
///     ProgressBar(progress: 0.4)
///         .frame(height: 6)
struct ProgressBar: View {
    /// Průběh 0–1.
    let progress: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Color.gustavNeutral
                    .clipShape(Capsule())
                Color.gustavVolt
                    .frame(width: proxy.size.width * progress)
                    .clipShape(Capsule())
            }
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        ProgressBar(progress: 0)
        ProgressBar(progress: 0.4)
        ProgressBar(progress: 1)
    }
    .frame(height: 50)
    .padding()
    .background(.black)
}
