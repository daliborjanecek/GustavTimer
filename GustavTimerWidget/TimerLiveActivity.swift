//
//  TimerLiveActivity.swift
//  GustavTimerWidget
//
//  Live Activity běžícího timeru – zamykací obrazovka a Dynamic Island.
//
//  Dlaždice nic neodpočítává a nic nedopočítává. Aplikace na pozadí neběží,
//  takže by neměl kdo posílat aktualizace: odpočet by doběhl na nulu a zůstal
//  na ní, název intervalu a číslo kola by zamrzly na hodnotě staré několik
//  minut. Zůstává proto jediné sdělení – timer běží, podrobnosti jsou v aplikaci.
//

import SwiftUI
import WidgetKit
import ActivityKit

struct TimerLiveActivity: Widget {

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TimerActivityAttributes.self) { context in
            LockScreenView(status: Status(phase: context.state.phase))
                .activityBackgroundTint(.black)
                .activitySystemActionForegroundColor(.gustavVolt)
        } dynamicIsland: { context in
            let status = Status(phase: context.state.phase)

            return DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    HStack(spacing: 10) {
                        Image(systemName: status.symbol)
                            .foregroundStyle(status.accent)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(status.headline)
                                .font(.gustavLabel(15))
                                .foregroundStyle(status.accent)
                            Text(status.detail)
                                .font(.gustavCaption(12))
                                .foregroundStyle(.secondary)
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 4)
                }
            } compactLeading: {
                Image(systemName: status.symbol)
                    .foregroundStyle(status.accent)
            } compactTrailing: {
                EmptyView()
            } minimal: {
                Image(systemName: status.symbol)
                    .foregroundStyle(status.accent)
            }
            .keylineTint(.gustavVolt)
        }
    }
}

// MARK: - Co dlaždice říká

private struct Status {
    let phase: TimerActivityAttributes.ContentState.Phase

    var headline: String {
        phase == .paused ? "TIMER PAUSED" : "TIMER RUNNING"
    }

    var detail: String {
        phase == .paused ? "Open the app to resume" : "Open the app for the countdown"
    }

    var symbol: String {
        phase == .paused ? "pause.circle.fill" : "timer"
    }

    var accent: Color {
        phase == .paused ? .gustavNeutral : .gustavVolt
    }
}

// MARK: - Zamykací obrazovka

private struct LockScreenView: View {
    let status: Status

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: status.symbol)
                .font(.system(size: 28))
                .foregroundStyle(status.accent)

            VStack(alignment: .leading, spacing: 4) {
                Text(status.headline)
                    .font(.gustavLabel(17))
                    .foregroundStyle(status.accent)

                Text(status.detail)
                    .font(.gustavCaption(12))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
    }
}

// MARK: - Náhledy
//
// Live Activity se v Xcode Canvas prohlíží přes `as:` – každá hodnota odpovídá
// jednomu místu, kde se dlaždice zobrazuje. Stavy uvedené v `contentStates`
// se dají v náhledu přepínat, takže je vidět běh i pauza vedle sebe.

#Preview("Zamykací obrazovka", as: .content, using: TimerActivityAttributes()) {
    TimerLiveActivity()
} contentStates: {
    TimerActivityAttributes.ContentState(phase: .running)
    TimerActivityAttributes.ContentState(phase: .paused)
}

#Preview("Dynamic Island – rozbalený", as: .dynamicIsland(.expanded), using: TimerActivityAttributes()) {
    TimerLiveActivity()
} contentStates: {
    TimerActivityAttributes.ContentState(phase: .running)
    TimerActivityAttributes.ContentState(phase: .paused)
}

#Preview("Dynamic Island – kompaktní", as: .dynamicIsland(.compact), using: TimerActivityAttributes()) {
    TimerLiveActivity()
} contentStates: {
    TimerActivityAttributes.ContentState(phase: .running)
    TimerActivityAttributes.ContentState(phase: .paused)
}

#Preview("Dynamic Island – minimální", as: .dynamicIsland(.minimal), using: TimerActivityAttributes()) {
    TimerLiveActivity()
} contentStates: {
    TimerActivityAttributes.ContentState(phase: .running)
    TimerActivityAttributes.ContentState(phase: .paused)
}
