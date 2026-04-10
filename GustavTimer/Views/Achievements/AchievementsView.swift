//
//  AchievementsView.swift
//  GustavTimer
//

import SwiftUI
import GustavUICore

struct AchievementsView: View {
    @StateObject private var manager = AchievementsManager()

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private var categories: [AchievementCategory] {
        [.milestone, .rounds, .dedication, .workout]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                statsRow
                    .padding(.horizontal)
                    .padding(.top, 8)

                ForEach(categories, id: \.rawValue) { category in
                    let items = Achievement.all.filter { $0.category == category }
                    categorySection(category: category, achievements: items)
                }
            }
            .padding(.bottom, 32)
        }
        .background(Color(UIColor.systemGroupedBackground))
        .navigationTitle(Text("ACHIEVEMENTS"))
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Stats row

    private var statsRow: some View {
        let unlockedCount = Achievement.all.filter { manager.isUnlocked($0.id) }.count
        let total = Achievement.all.count
        return HStack(spacing: 0) {
            VStack(spacing: 2) {
                Text("\(unlockedCount)/\(total)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.gustavVolt)
                Text("ACH_UNLOCKED")
                    .font(.caption)
                    .foregroundStyle(Color.gustavNeutral)
            }
            .frame(maxWidth: .infinity)

            Divider().frame(height: 40)

            VStack(spacing: 2) {
                Text("\(manager.totalRoundsCompleted)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.gustavVolt)
                Text("ACH_TOTAL_ROUNDS")
                    .font(.caption)
                    .foregroundStyle(Color.gustavNeutral)
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
        )
    }

    // MARK: - Category section

    private func categorySection(category: AchievementCategory, achievements: [Achievement]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(LocalizedStringKey(category.titleKey))
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(Color.gustavNeutral)
                .textCase(.uppercase)
                .tracking(0.5)
                .padding(.horizontal)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(achievements) { achievement in
                    AchievementCell(achievement: achievement, manager: manager)
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Achievement Cell

private struct AchievementCell: View {
    let achievement: Achievement
    let manager: AchievementsManager

    private var unlocked: Bool { manager.isUnlocked(achievement.id) }
    private var unlockedDate: Date? { manager.unlockedDate(achievement.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: achievement.icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(unlocked ? Color.gustavVolt : Color.gustavNeutral.opacity(0.4))
                Spacer()
                if !unlocked {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(Color.gustavNeutral.opacity(0.3))
                }
            }

            Text(LocalizedStringKey(achievement.nameKey))
                .font(.gustavBody)
                .fontWeight(.semibold)
                .foregroundStyle(unlocked ? Color.primary : Color.gustavNeutral.opacity(0.5))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Text(LocalizedStringKey(achievement.descriptionKey))
                .font(.caption)
                .foregroundStyle(unlocked ? Color.secondary : Color.gustavNeutral.opacity(0.35))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            if let date = unlockedDate {
                Text(date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundStyle(Color.gustavVolt.opacity(0.7))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(
                            unlocked ? Color.gustavVolt.opacity(0.25) : Color.clear,
                            lineWidth: 1
                        )
                )
        )
        .opacity(unlocked ? 1.0 : 0.7)
    }
}

// MARK: - Category title keys

private extension AchievementCategory {
    var titleKey: String {
        switch self {
        case .milestone:  return "ACH_CATEGORY_MILESTONE"
        case .rounds:     return "ACH_CATEGORY_ROUNDS"
        case .dedication: return "ACH_CATEGORY_DEDICATION"
        case .workout:    return "ACH_CATEGORY_WORKOUT"
        }
    }
}

#Preview {
    NavigationStack {
        AchievementsView()
    }
}
