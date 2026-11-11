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

/// Velké ovládací tlačítko timeru. Buď s textem (start/stop), nebo
/// s animovanou ikonou (reset/skip).
///
///     ControlButton(label: "START", description: "Work", action: start)
///     ControlButton(icon: isRunning ? .skip : .reset, color: .gustavNeutral, action: secondary)
struct ControlButton: View {

    /// Animovaná ikona tlačítka. Změna ikony přehraje přechod mezi nimi.
    enum Icon {
        case skip, reset
    }

    private enum Content {
        case text(label: LocalizedStringKey, description: LocalizedStringKey?)
        case icon(Icon)
    }

    private let content: Content
    private let color: Color
    private let action: () -> Void

    @State private var lottiePlayback = LottiePlaybackMode.paused(at: .frame(0))

    init(label: LocalizedStringKey, description: LocalizedStringKey? = nil, color: Color = .gustavVolt, action: @escaping () -> Void) {
        self.content = .text(label: label, description: description)
        self.color = color
        self.action = action
    }

    init(icon: Icon, color: Color = .gustavVolt, action: @escaping () -> Void) {
        self.content = .icon(icon)
        self.color = color
        self.action = action
    }

    var body: some View {
        Button {
            playClickAnimation()
            action()
        } label: {
            switch content {
            case .text(let label, let description):
                textLabel(label, description: description)
            case .icon:
                iconLabel
            }
        }
        .buttonStyle(.plain)
        .onChange(of: icon) { _, newIcon in
            playTransition(to: newIcon)
        }
    }

    private func textLabel(_ label: LocalizedStringKey, description: LocalizedStringKey?) -> some View {
        HStack {
            Text(label)
                .font(.buttonLabel)
            Text(description ?? "")
                .font(.buttonDescription)
                .textCase(.uppercase)
                .opacity(0.5)
        }
        .foregroundStyle(color == .gustavVolt ? Color.gustavNeutral : Color.gustavVolt)
        .frame(height: GustavLayout.controlHeight)
        .frame(maxWidth: .infinity)
        .controlSurface(color)
    }

    private var iconLabel: some View {
        Color.clear
            .frame(height: GustavLayout.controlHeight)
            .controlSurface(color)
            .overlay {
                GustavAnimationView(.resetSkip, mode: $lottiePlayback)
                    .padding(24)
            }
            .onAppear {
                lottiePlayback = .gustav(.appear)
            }
    }

    private var icon: Icon? {
        if case .icon(let icon) = content { return icon }
        return nil
    }

    private func playClickAnimation() {
        switch icon {
        case .skip:  lottiePlayback = .gustav(.clickSkip)   // snímky 120–180
        case .reset: lottiePlayback = .gustav(.clickReset)  // snímky 0–60
        case nil:    break
        }
    }

    private func playTransition(to icon: Icon?) {
        switch icon {
        case .skip:  lottiePlayback = .gustav(.transitionToSkip)   // snímky 60–120
        case .reset: lottiePlayback = .gustav(.transitionToReset)  // snímky 180–239
        case nil:    break
        }
    }
}

private extension View {
    /// Podklad tlačítka: na iOS 26 tónované sklo, jinak plná barva ve tvaru pilulky.
    @ViewBuilder
    func controlSurface(_ color: Color) -> some View {
        if #available(iOS 26.0, *) {
            self
                .glassEffect(.regular.tint(color).interactive())
                .contentShape(Rectangle())
        } else {
            self
                .background(color)
                .clipShape(Capsule())
                .contentShape(Rectangle())
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        ControlButton(label: "START", description: "Work", action: {})
        ControlButton(label: "STOP", color: .gustavPink, action: {})
        HStack(spacing: 16) {
            ControlButton(label: "COUNTDOWN", action: {})
            ControlButton(icon: .reset, color: .gustavNeutral, action: {})
                .frame(width: 100)
        }
    }
    .padding()
    .background(.black)
}
