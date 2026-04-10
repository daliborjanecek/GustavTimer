//
//  AchievementToastView.swift
//  GustavTimer
//

import SwiftUI
import GustavUICore

struct AchievementToastView: View {
    let achievement: Achievement

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: achievement.icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color.gustavNeutral)
                .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text("ACH_TOAST_TITLE")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.gustavNeutral)
                    .textCase(.uppercase)
                    .tracking(0.5)

                Text(LocalizedStringKey(achievement.nameKey))
                    .font(.gustavBody)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.gustavVolt)
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.gustavVolt.opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
    }
}

#Preview {
    ZStack(alignment: .bottom) {
        Color.black.ignoresSafeArea()
        AchievementToastView(achievement: Achievement.all[0])
            .padding(.bottom, 100)
    }
}
