//
//  TimerLiveActivity.swift
//  GustavTimerWidget
//
//  Live Activity běžícího timeru – zamykací obrazovka a Dynamic Island.
//
//  Hlavní číslo je odpočet aktuálního intervalu, pod ním drobně čas celého
//  tréninku. Interval ale platí jen do svého konce: další přechod musí poslat
//  aplikace a ta na pozadí spí. Konec intervalu je proto `staleDate` aktivity
//  a jakmile systém dlaždici označí za stale, hlavní číslo převezme zbývající
//  (u nekonečných kol uplynulý) čas tréninku – ten stojí jen na dvou absolutních
//  datech a platí i po hodině bez jediné aktualizace.
//
//  Pozor: `Text(timerInterval:)` ani `ProgressView(timerInterval:)` nesmí dostat
//  `.fixedSize()` – dlaždice se pak přestane vykreslovat a zůstane viset
//  poslední snímek. Šířku omezuje jen `.frame(maxWidth:)`.
//

import SwiftUI
import WidgetKit
import ActivityKit

struct TimerLiveActivity: Widget {

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TimerActivityAttributes.self) { context in
            LockScreenView(display: Display(state: context.state, isStale: context.isStale))
                .activityBackgroundTint(.black)
                .activitySystemActionForegroundColor(.gustavVolt)
        } dynamicIsland: { context in
            let display = Display(state: context.state, isStale: context.isStale)

            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Image(systemName: display.symbol)
                        Text(display.headline)
                            .font(.gustavLabel(13))
                            .textCase(.uppercase)
                            .lineLimit(1)
                    }
                    .foregroundStyle(display.accent)
                    .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if display.showsInterval {
                        TotalLine(state: display.state)
                            .padding(.trailing, 4)
                    } else {
                        Text(display.totalCaption)
                            .font(.gustavCaption(12))
                            .foregroundStyle(.secondary)
                            .padding(.trailing, 4)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    MainCountdown(display: display, alignment: .leading)
                        .font(.gustavLabel(34))
                        .foregroundStyle(display.accent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                }
            } compactLeading: {
                Image(systemName: display.symbol)
                    .foregroundStyle(display.accent)
            } compactTrailing: {
                MainCountdown(display: display, alignment: .trailing)
                    .font(.gustavLabel(14))
                    .foregroundStyle(display.accent)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 64)
            } minimal: {
                Image(systemName: display.symbol)
                    .foregroundStyle(display.accent)
            }
            .keylineTint(.gustavVolt)
        }
    }
}

// MARK: - Co dlaždice říká

private struct Display {
    let state: TimerActivityAttributes.ContentState
    /// Konec intervalu minul a aplikace nestihla poslat přechod.
    let isStale: Bool

    private var isPaused: Bool { state.phase == .paused }

    /// Aktuální interval je platný – ještě neskončil, nebo timer stojí v pauze.
    var showsInterval: Bool { !isStale }

    var headline: String {
        if showsInterval {
            return state.intervalName.isEmpty ? "Interval" : state.intervalName
        }
        return isPaused ? "Paused" : "Running"
    }

    var totalCaption: String {
        state.isCountingDown ? "Time left" : "Elapsed"
    }

    var symbol: String {
        isPaused ? "pause.circle.fill" : "timer"
    }

    var accent: Color {
        isPaused ? .gustavNeutral : .gustavVolt
    }
}

// MARK: - Odpočty

/// Systémový odpočet nad absolutními daty – při pauze se zastaví na `pausedAt`.
private struct TimerText: View {
    let range: ClosedRange<Date>
    let pausedAt: Date?
    let countsDown: Bool
    var showsHours = true

    var body: some View {
        Text(
            timerInterval: range,
            pauseTime: pausedAt,
            countsDown: countsDown,
            showsHours: showsHours
        )
        .monospacedDigit()
        .lineLimit(1)
    }
}

/// Hlavní číslo dlaždice: odpočet intervalu, po jeho vypršení čas celého
/// tréninku.
///
/// Jen v sekundách („17“) ho ukázat nejde. Systém v Live Activity sám
/// přepočítává pouze `Text(timerInterval:)` (formát m:ss). Zdroje času z iOS 18
/// (`Text(.dateRange(endingAt:), format:)`) se po pár sekundách zastaví.
private struct MainCountdown: View {
    let display: Display
    /// Kam v prostoru odpočtu umístit `IntervalEndedView`.
    var alignment: Alignment = .center

    var body: some View {
        if display.showsInterval {
            let range = display.state.intervalRange
            let isRunning = display.state.pausedAt == nil

            ZStack(alignment: alignment) {
                TimerText(
                    range: range,
                    pausedAt: display.state.pausedAt,
                    countsDown: true,
                    showsHours: false
                )
                .vanishing(at: range, isActive: isRunning)

                // V pauze interval neskončí – obsah „po konci“ nemá kdy ukázat.
                if isRunning {
                    IntervalEndedView(state: display.state)
                        .appearing(at: range)
                }
            }
        } else {
            TimerText(
                range: display.state.timerRange,
                pausedAt: display.state.pausedAt,
                countsDown: display.state.isCountingDown
            )
        }
    }
}

/// Obsah, který naskočí místo odpočtu, když interval doběhne a uspaná aplikace
/// nestihla poslat další. Dokud interval běží, je skrytý.
///
/// Sem patří libovolný SwiftUI obsah – jen statický: dlaždice se v tu chvíli
/// nepřekresluje, takže nic, co by se počítalo z `Date()`, nebude aktuální.
/// Písmo a barvu dědí od místa použití (zamykací obrazovka, Dynamic Island).
private struct IntervalEndedView: View {
    let state: TimerActivityAttributes.ContentState

    var body: some View {
        Image(systemName: "checkmark.circle.fill")
    }
}

// MARK: - Zmizení odpočtu a naskočení obsahu na konci intervalu
//
// EXPERIMENT – nikde nezdokumentované, ověřené na zařízení jen pro zmizení.
//
// Uspaná aplikace přechod na další interval nepošle a `Text(timerInterval:)`
// by zůstal na 0:00. Překreslení přes `staleDate` systém nedělá spolehlivě.
// Jediné, co se v dlaždici v čase mění samo, jsou systémové odpočty – proto
// obsah maskuje `ProgressView(timerInterval:)` široký 200 000 bodů:
//
// - Zmizení: progress bar začíná u levého okraje obsahu, výplň se zmenšuje
//   k nule a pokrývá obsah, dokud je delší než obsah – tedy skoro celý interval.
// - Naskočení: progress bar končí u pravého okraje obsahu, výplň roste zleva
//   a obsah zakryje (= odkryje) až v posledním zlomku intervalu.
// - Šířka je pevná, ne `scaleEffect(x:)`: roztažením by se zakulacené konce
//   progress baru protáhly na tisíce bodů a obsah by ořízla dlouhá špička.
//   Takhle mají pár bodů a posun o `capClearance` je dostane mimo obsah.
// - Neprázdná dráha progress baru je poloprůhledná. Trojí maska její zbytkovou
//   neprůhlednost umocní na třetí (např. 0,3 → 0,027), výplň zůstane plná.
//
// Pokud by se dlaždice přestala vykreslovat, stačí smazat volání
// `.vanishing(…)` a `.appearing(…)` v `MainCountdown`.

private extension View {
    /// Skryje obsah na konci `range`. Při pauze se nemaskuje – odpočet stojí.
    @ViewBuilder
    func vanishing(at range: ClosedRange<Date>, isActive: Bool) -> some View {
        if isActive {
            self
                .mask(alignment: .leading) { IntervalMask(range: range, revealsAtEnd: false) }
                .mask(alignment: .leading) { IntervalMask(range: range, revealsAtEnd: false) }
                .mask(alignment: .leading) { IntervalMask(range: range, revealsAtEnd: false) }
        } else {
            self
        }
    }

    /// Ukáže obsah až na konci `range`.
    func appearing(at range: ClosedRange<Date>) -> some View {
        self
            .mask(alignment: .trailing) { IntervalMask(range: range, revealsAtEnd: true) }
            .mask(alignment: .trailing) { IntervalMask(range: range, revealsAtEnd: true) }
            .mask(alignment: .trailing) { IntervalMask(range: range, revealsAtEnd: true) }
    }
}

private struct IntervalMask: View {
    let range: ClosedRange<Date>
    /// `false` = plná po celý interval, na konci prázdná (zmizení).
    /// `true` = prázdná po celý interval, na konci plná (naskočení).
    let revealsAtEnd: Bool

    /// Délka progress baru. Obsah (nejvýš ~150 bodů) tvoří necelou tisícinu,
    /// takže se přepne v posledních ~0,1 % intervalu (u 10minutového ~0,5 s).
    private static let length: CGFloat = 200_000

    /// O kolik zakulacený konec progress baru přesahuje přes okraj obsahu.
    private static let capClearance: CGFloat = 8

    var body: some View {
        ProgressView(timerInterval: range, countsDown: !revealsAtEnd) {
            EmptyView()
        } currentValueLabel: {
            EmptyView()
        }
        .progressViewStyle(.linear)
        .tint(.white)
        .frame(width: Self.length)
        // Výška progress baru je pár bodů – svisle ho roztáhneme přes celý obsah.
        .scaleEffect(x: 1, y: 40)
        .offset(x: revealsAtEnd ? Self.capClearance : -Self.capClearance)
    }
}

/// Drobný řádek s časem celého tréninku, např. „Time left 6:25“.
private struct TotalLine: View {
    let state: TimerActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 4) {
            Text(state.isCountingDown ? "Time left" : "Elapsed")
            TimerText(range: state.timerRange, pausedAt: state.pausedAt, countsDown: state.isCountingDown)
                .frame(maxWidth: 64, alignment: .leading)
        }
        .font(.gustavCaption(12))
        .foregroundStyle(.secondary)
    }
}

// MARK: - Zamykací obrazovka

private struct LockScreenView: View {
    let display: Display

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: display.symbol)
                .font(.system(size: 28))
                .foregroundStyle(display.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text(display.headline)
                    .font(.gustavLabel(15))
                    .textCase(.uppercase)
                    .lineLimit(1)
                    .foregroundStyle(display.accent)

                if display.showsInterval {
                    TotalLine(state: display.state)
                } else {
                    Text(display.totalCaption)
                        .font(.gustavCaption(12))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 8)

            MainCountdown(display: display, alignment: .trailing)
                .font(.gustavLabel(34))
                .foregroundStyle(display.accent)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 150, alignment: .trailing)
        }
        .padding(16)
    }
}

// MARK: - Náhledy
//
// Live Activity se v Xcode Canvas prohlíží přes `as:` – každá hodnota odpovídá
// jednomu místu, kde se dlaždice zobrazuje. Stavy uvedené v `contentStates`
// se dají v náhledu přepínat: běh, pauza a nekonečný počet kol.
// Stale stav (záloha po vypršení intervalu) náhled nasimulovat neumí.

private extension TimerActivityAttributes.ContentState {
    static let previewRunning = Self(
        phase: .running,
        intervalName: "Work",
        intervalStart: .now.addingTimeInterval(-12),
        intervalEnd: .now.addingTimeInterval(18),
        start: .now.addingTimeInterval(-95),
        end: .now.addingTimeInterval(385),
        pausedAt: nil
    )
    static let previewPaused = Self(
        phase: .paused,
        intervalName: "Rest",
        intervalStart: .now.addingTimeInterval(-4),
        intervalEnd: .now.addingTimeInterval(11),
        start: .now.addingTimeInterval(-95),
        end: .now.addingTimeInterval(385),
        pausedAt: .now
    )
    static let previewEndless = Self(
        phase: .running,
        intervalName: "Work",
        intervalStart: .now.addingTimeInterval(-25),
        intervalEnd: .now.addingTimeInterval(35),
        start: .now.addingTimeInterval(-754),
        end: nil,
        pausedAt: nil
    )
}

#Preview("Zamykací obrazovka", as: .content, using: TimerActivityAttributes()) {
    TimerLiveActivity()
} contentStates: {
    TimerActivityAttributes.ContentState.previewRunning
    TimerActivityAttributes.ContentState.previewPaused
    TimerActivityAttributes.ContentState.previewEndless
}

#Preview("Dynamic Island – rozbalený", as: .dynamicIsland(.expanded), using: TimerActivityAttributes()) {
    TimerLiveActivity()
} contentStates: {
    TimerActivityAttributes.ContentState.previewRunning
    TimerActivityAttributes.ContentState.previewPaused
    TimerActivityAttributes.ContentState.previewEndless
}

#Preview("Dynamic Island – kompaktní", as: .dynamicIsland(.compact), using: TimerActivityAttributes()) {
    TimerLiveActivity()
} contentStates: {
    TimerActivityAttributes.ContentState.previewRunning
    TimerActivityAttributes.ContentState.previewPaused
    TimerActivityAttributes.ContentState.previewEndless
}

#Preview("Dynamic Island – minimální", as: .dynamicIsland(.minimal), using: TimerActivityAttributes()) {
    TimerLiveActivity()
} contentStates: {
    TimerActivityAttributes.ContentState.previewRunning
    TimerActivityAttributes.ContentState.previewPaused
}
