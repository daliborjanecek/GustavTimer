//
//  ControlButton.swift
//  GustavTimer
//
//  Created by Dalibor Janeček on 14.09.2024.
//

import SwiftUI
import Lottie
import GustavUICore
import GustavUIAnimations

struct ControlButton: View {
    let action: () -> ()
    var label: LocalizedStringKey? = nil
    var riveAnimation: String?
    var description: LocalizedStringKey? = nil
    let color: Color
    @State var lottiePlayback = LottiePlaybackMode.paused(at: .frame(0))
    @Binding var buttonType: ButtonType
        
    init(action: @escaping () -> (), label: LocalizedStringKey? = nil, riveAnimation: String? = nil, description: LocalizedStringKey? = nil, color: Color = .gustavVolt, buttonType: Binding<ButtonType>) {
        self.action = action
        self.label = label
        self.riveAnimation = riveAnimation
        self.description = description
        self.color = color
        self._buttonType = buttonType
    }
    
    var body: some View {
        Button(action: {
            playLottieAnimation()
            action()
        }, label: {
            if riveAnimation != nil {
                if #available(iOS 26.0, *) {
                    Color.clear
                        .frame(height: GustavLayout.controlHeight)
                        .glassEffect(.regular.tint(color).interactive())
                        .overlay(
                            GustavAnimationView(.resetSkip, mode: $lottiePlayback)
                                .padding(24)
                        )
                        .contentShape(Rectangle())
                        .onAppear {
                            lottiePlayback = LottiePlaybackMode.gustav(.appear)
                        }
                } else {
                    // Fallback on earlier versions
                    Color.clear
                        .frame(height: GustavLayout.controlHeight)
                        .background(color)
                        .overlay(
                            GustavAnimationView(.resetSkip, mode: $lottiePlayback)
                                .padding(24)
                        )
                        .contentShape(Rectangle())
                        .onAppear {
                            lottiePlayback = LottiePlaybackMode.gustav(.appear)
                        }
                        .clipShape(Capsule())
                        .contentShape(Rectangle())
                }
            } else {
                if #available(iOS 26.0, *) {
                    HStack {
                        Text(label ?? "")
                            .font(.buttonLabel)
                            .foregroundStyle(color == .gustavVolt ? Color.gustavNeutral : Color.gustavVolt)
                        Text(description ?? "")
                            .font(.buttonDescription)
                            .foregroundStyle(color == .gustavVolt ? Color.gustavNeutral : Color.gustavVolt)
                            .textCase(.uppercase)
                            .opacity(0.5)
                    }
                    .frame(height: GustavLayout.controlHeight)
                    .frame(maxWidth: .infinity)
                    .glassEffect(.regular.tint(color).interactive())
                    .contentShape(Rectangle())
                } else {
                    // Fallback on earlier versions
                    HStack {
                        Text(label ?? "")
                            .font(.buttonLabel)
                            .foregroundStyle(color == .gustavVolt ? Color.gustavNeutral : Color.gustavVolt)
                        Text(description ?? "")
                            .font(.buttonDescription)
                            .foregroundStyle(color == .gustavVolt ? Color.gustavNeutral : Color.gustavVolt)
                            .textCase(.uppercase)
                            .opacity(0.5)
                    }
                    .frame(height: GustavLayout.controlHeight)
                    .frame(maxWidth: .infinity)
                    .background(color)
                    .clipShape(Capsule())
                    .contentShape(Rectangle())
                }
            }
        })
        .buttonStyle(.plain)
        .onChange(of: buttonType) {
            buttonTypeChanged()
        }
    }
    
    private func playLottieAnimation() {
        switch buttonType {
        case .text:
            return
        case .skip:
            lottiePlayback = LottiePlaybackMode.gustav(.clickSkip) // Hraje 120-180
        case .reset:
            lottiePlayback = LottiePlaybackMode.gustav(.clickReset) // Hraje 0-60
        }
    }
    
    private func buttonTypeChanged() {
        switch buttonType {
        case .text:
            return
        case .skip:
            lottiePlayback = LottiePlaybackMode.gustav(.transitionToSkip) // Hraje 60-120
        case .reset:
            lottiePlayback = LottiePlaybackMode.gustav(.transitionToReset) // Hraje 180-239
        }
    }
    
    enum ButtonType {
        case text, skip, reset
    }
}

//#Preview {
//    VStack {
//        Spacer()
//        ControlButton(action: {}, label: "start", description: "30 s", color: .stop)
//            .padding()
//        ControlButton(action: {}, label: "start", riveAnimation: "reset", color: .reset)
//            .padding()
//
//        Spacer()
//    }
//    .background(.gray)
//}
