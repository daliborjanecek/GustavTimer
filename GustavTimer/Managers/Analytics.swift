//
//  Analytics.swift
//  GustavTimer
//
//  Created by Dalibor Janeček on 09.11.2026.
//
//  Jediné místo, kudy aplikace posílá signály do TelemetryDeck.
//
//  Názvy signálů jsou v `AnalyticsSignal`, parametry skládají čisté funkce
//  níže (testuje je `AnalyticsTests`). Přehled signálů a jejich parametrů
//  je v `GustavTimer-Dokumentace.md`, sekce 13.
//
//  Soukromí: posílá se jen tvar tréninku a volby v aplikaci. Názvy, které
//  psal uživatel (timer, intervaly), se nikdy neposílají – název se posílá
//  jen u presetů, ty pocházejí z aplikace.
//
//      Analytics.send(.timerSaved, parameters: Analytics.parameters(for: settings))
//

import Foundation
import TelemetryDeck

/// Názvy signálů. Stávající názvy se nemění, aby navazovala historie v dashboardu.
enum AnalyticsSignal: String {
    // Trénink
    case timerStarted = "timer.started"
    case timerCompleted = "timer.completed"
    case timerStopped = "timer.stopped"

    // Výběr a ukládání timeru
    case timerSaved = "timer.saved"
    case presetSelected = "timer.preloadselected"
    case favouriteSelected = "timer.favourite_selected"
    case soundSelected = "timer.sound_selected"

    // Sdílení
    case timerShared = "timer.shared"
    case shareCancelled = "timer.share_cancelled"
    case linkOpened = "timer.link_opened"

    // Nastavení
    case settingChanged = "settings.changed"
    case displayFormatChanged = "settings.display_format_changed"

    // Aplikace
    case externalLinkOpened = "link.opened"
    case whatsNewShown = "whatsnew.shown"
    case reviewRequested = "review.requested"
}

/// Odkud pochází nastavení, se kterým se trénink spustil.
enum TimerOrigin: String {
    /// Shoduje se s presetem z aplikace.
    case preset
    /// Shoduje se s uloženým oblíbeným.
    case favourite
    /// Načtené ze sdíleného odkazu.
    case link
    /// Ručně upravené.
    case custom
}

/// Čím uživatel timer spustil.
enum TimerInput: String {
    /// Tlačítko START na výšku.
    case button
    /// Tap na odpočet na výšku.
    case tap
    /// Tap na odpočet na šířku, kde tlačítka nejsou.
    case landscapeTap = "landscape_tap"
}

/// Obrazovka, ze které uživatel vybral timer.
enum TimerSelectionScreen: String {
    case favourites
    case search
    case settings
}

enum Analytics {

    // MARK: - Odeslání

    static func send(_ signal: AnalyticsSignal, parameters: [String: String] = [:], floatValue: Double? = nil) {
        TelemetryDeck.signal(signal.rawValue, parameters: parameters, floatValue: floatValue)
    }

    // MARK: - Parametry timeru

    /// Délky intervalů jednoho kola, např. `30/15`.
    static func intervalPattern(_ intervals: [IntervalData]) -> String {
        intervals.map { String($0.value) }.joined(separator: "/")
    }

    /// Tvar tréninku a jeho volby – společný základ signálů o timeru.
    ///
    ///     Analytics.parameters(for: tabata)
    ///     // ["interval_pattern": "20/10", "interval_count": "2", "rounds": "8",
    ///     //  "round_seconds": "30", "total_duration": "1-5m", "sound": "beep",
    ///     //  "haptics": "true", "ticking": "off", "countdown": "true"]
    static func parameters(for settings: TimerSettings) -> [String: String] {
        let roundSeconds = settings.intervals.reduce(0) { $0 + $1.value }
        return [
            "interval_pattern": intervalPattern(settings.intervals),
            "interval_count": String(settings.intervals.count),
            "rounds": roundsValue(settings.rounds),
            "round_seconds": String(roundSeconds),
            "total_duration": settings.rounds > 0
                ? durationBucket(seconds: Double(roundSeconds * settings.rounds))
                : "loop",
            "sound": settings.sound?.rawValue ?? "mute",
            "haptics": boolValue(settings.isVibrating),
            "ticking": settings.ticking.rawValue,
            "countdown": boolValue(settings.hasCountdown)
        ]
    }

    /// Počet kol jako parametr. `-1` (nekonečno) je `loop`.
    static func roundsValue(_ rounds: Int) -> String {
        rounds == -1 ? "loop" : String(rounds)
    }

    static func boolValue(_ value: Bool) -> String {
        value ? "true" : "false"
    }

    /// Délka zaokrouhlená do skupin, aby šly tréninky porovnávat v grafu.
    ///
    ///     durationBucket(seconds: 240)   // "1-5m"
    ///     durationBucket(seconds: 1800)  // "30-60m"
    static func durationBucket(seconds: Double) -> String {
        switch seconds {
        case ..<60:   return "<1m"
        case ..<300:  return "1-5m"
        case ..<900:  return "5-15m"
        case ..<1800: return "15-30m"
        case ..<3600: return "30-60m"
        default:      return "60m+"
        }
    }

    /// Podíl zaokrouhlený dolů na desítky procent: `0.37` → `"30"`.
    static func percentBucket(_ fraction: Double) -> String {
        let clamped = min(max(fraction, 0), 1)
        return String(Int((clamped * 10).rounded(.down)) * 10)
    }

    // MARK: - Průběh tréninku

    /// Kolik sekund tréninku uběhlo a jaká je to část celku.
    ///
    /// `round` je číslo právě běžícího kola tak, jak ho vede engine
    /// (`finishedRounds` – po prvním startu `1`, před ním `0`). Podíl je `nil`
    /// u nekonečných kol, kde žádný celek není.
    ///
    ///     // Tabata 20/10 × 8, ve 3. kole ve druhém intervalu, zbývají 4 s
    ///     workoutProgress(intervals: tabata, rounds: 8, round: 3, activeIndex: 1, remainingSeconds: 4)
    ///     // (elapsed: 86, fraction: 0.358)
    static func workoutProgress(
        intervals: [IntervalData],
        rounds: Int,
        round: Int,
        activeIndex: Int,
        remainingSeconds: Double
    ) -> (elapsed: Double, fraction: Double?) {
        guard round > 0, intervals.indices.contains(activeIndex) else { return (0, rounds > 0 ? 0 : nil) }

        let roundSeconds = Double(intervals.reduce(0) { $0 + $1.value })
        let finishedIntervals = Double(intervals[..<activeIndex].reduce(0) { $0 + $1.value })
        let current = max(Double(intervals[activeIndex].value) - remainingSeconds, 0)
        let elapsed = Double(round - 1) * roundSeconds + finishedIntervals + current

        guard rounds > 0, roundSeconds > 0 else { return (elapsed, nil) }
        return (elapsed, min(elapsed / (roundSeconds * Double(rounds)), 1))
    }

    // MARK: - Původ timeru

    /// Podle čeho se timer spouští. Preset má přednost před oblíbeným –
    /// uložený preset je pořád preset. Porovnává se tvar tréninku bez názvu.
    ///
    /// - Returns: původ a u presetu jeho `PredefinedTimer.rawValue`.
    static func origin(
        of settings: TimerSettings,
        presets: [(id: String, settings: TimerSettings)],
        favourites: [TimerSettings],
        lastLink: TimerSettings?
    ) -> (origin: TimerOrigin, presetID: String?) {
        if let preset = presets.first(where: { $0.settings.matchesWorkout(of: settings) }) {
            return (.preset, preset.id)
        }
        if favourites.contains(where: { $0.matchesWorkout(of: settings) }) {
            return (.favourite, nil)
        }
        if let lastLink, lastLink.matchesWorkout(of: settings) {
            return (.link, nil)
        }
        return (.custom, nil)
    }

    // MARK: - Výběr a ukládání timeru

    static func presetSelected(_ preset: PredefinedTimer, screen: TimerSelectionScreen) {
        let settings = preset.settings
        send(.presetSelected, parameters: [
            "timer_name": settings.name,
            "preset": preset.rawValue,
            "interval_pattern": intervalPattern(settings.intervals),
            "screen": screen.rawValue
        ])
    }

    /// Volat až po `TimerData.selected()`, ať `use_count` zahrnuje i tohle použití.
    static func favouriteSelected(_ timer: TimerData, screen: TimerSelectionScreen) {
        send(.favouriteSelected, parameters: [
            "interval_pattern": intervalPattern(timer.intervals),
            "use_count": String(timer.usedCount),
            "screen": screen.rawValue
        ])
    }

    static func timerSaved(_ settings: TimerSettings, screen: TimerSelectionScreen) {
        var parameters = self.parameters(for: settings)
        parameters["screen"] = screen.rawValue
        send(.timerSaved, parameters: parameters)
    }

    // MARK: - Nastavení

    /// `settings.changed` – změna jedné volby timeru nebo aplikace.
    ///
    ///     Analytics.settingChanged("haptics", value: false)
    ///     Analytics.settingChanged("rounds", value: -1)   // value = "loop"
    static func settingChanged(_ setting: String, value: Any) {
        send(.settingChanged, parameters: [
            "setting": setting,
            "value": settingValue(setting, value)
        ])
    }

    static func settingValue(_ setting: String, _ value: Any) -> String {
        switch value {
        case let rounds as Int where setting == "rounds":
            return roundsValue(rounds)
        case let bool as Bool:
            return boolValue(bool)
        case let raw as any RawRepresentable:
            return "\(raw.rawValue)"
        default:
            return "\(value)"
        }
    }
}

// MARK: - Akvizice

/// Pozná uživatele, který aplikaci nainstaloval kvůli sdílenému odkazu.
///
/// Odkaz instalaci nepřežije (App Store ho do aplikace nepředá), takže se
/// počítá s tím, že uživatel na odkaz po instalaci klepne znovu. Za akvizici
/// odkazem se proto bere první načtený odkaz do 24 hodin od první spuštění.
/// Instalace bez odkazu pozná TelemetryDeck sám (`newInstallDetected`).
enum AnalyticsAcquisition {

    static let window: TimeInterval = 24 * 60 * 60

    /// Volat při startu aplikace, před onboardingem. Stávajícím uživatelům
    /// (aktualizace z verze bez tohoto klíče) akvizici rovnou uzavře.
    static func registerLaunch(defaults: UserDefaults = .standard, now: Date = .now) {
        guard defaults.object(forKey: AppPreferences.Key.installDate) == nil else { return }
        defaults.set(now.timeIntervalSince1970, forKey: AppPreferences.Key.installDate)
        if defaults.object(forKey: AppPreferences.Key.lastOnboardingVersion) != nil {
            defaults.set(true, forKey: AppPreferences.Key.acquisitionReported)
        }
    }

    /// `TelemetryDeck.acquiredUser(channel:)` pro čerstvou instalaci, nejvýš jednou.
    static func reportLinkIfEligible(channel: String, defaults: UserDefaults = .standard, now: Date = .now) {
        guard isEligible(defaults: defaults, now: now) else { return }
        defaults.set(true, forKey: AppPreferences.Key.acquisitionReported)
        TelemetryDeck.acquiredUser(channel: channel)
    }

    static func isEligible(defaults: UserDefaults, now: Date) -> Bool {
        guard !defaults.bool(forKey: AppPreferences.Key.acquisitionReported),
              let installed = defaults.object(forKey: AppPreferences.Key.installDate) as? Double
        else { return false }
        return now.timeIntervalSince1970 - installed < window
    }
}
