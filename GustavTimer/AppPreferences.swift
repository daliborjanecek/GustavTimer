//
//  AppPreferences.swift
//  GustavTimer
//
//  Created by Dalibor Janeček on 18.09.2025.
//
//  Nastavení **zařízení**, ne timeru.
//
//  Pravidlo rozdělení: co definuje trénink (intervaly, kola, zvuk, vibrace,
//  tikání, odpočet), patří do `TimerData` / `TimerSettings` a jde sdílet
//  odkazem. Co je vlastnost téhle instalace aplikace, zůstává tady.
//
//  Do verze 2.3 se tady držel i `rounds`, `isVibrating`, `isTicking`
//  a `isSoundEnabled` – tedy nastavení timeru, které se pak neukládalo do
//  oblíbených a nepřenášelo odkazem. Přesun řeší `SettingsMigration`.
//

import SwiftUI

final class AppPreferences: ObservableObject {

    /// Vybrané pozadí. `-1` = vlastní fotka uživatele.
    @AppStorage(Key.backgroundIndex) var backgroundIndex: Int = 0

    /// Formát zobrazení zbývajícího času.
    @AppStorage(Key.timeDisplayFormat) var timeDisplayFormat: TimeDisplayFormat = .seconds

    /// Poslední vybraný zvuk. Nastavení zařízení ve smyslu „jaký zvuk mám rád“ –
    /// slouží jen k tomu, aby přepínač ztlumení v `SoundSettingsView` uměl
    /// vrátit tentýž zvuk. Zvuk **timeru** je `TimerSettings.sound`.
    @AppStorage(Key.lastSelectedSound) var lastSelectedSound: SoundModel = .beep

    /// Klíče UserDefaults na jednom místě – dřív byly rozepsané jako řetězce
    /// napříč šesti soubory a `"isSoundEnabled"` se vyskytovalo čtyřikrát.
    enum Key {
        static let backgroundIndex = "bgIndex"
        static let timeDisplayFormat = "timeDisplayFormat"
        static let lastSelectedSound = "lastSelectedSound"
        static let completedTimerCount = "completedTimerCount"
        static let stopCounter = "stopCounter"
        static let whatsNewVersion = "whatsNewVersion"
        static let lastOnboardingVersion = "lastOnboardingVersion"
        static let deeplinkLoadToken = "deeplinkLoadToken"
        static let deeplinkLoadedTitle = "deeplinkLoadedTitle"
        static let lastAcknowledgedDeeplinkToken = "lastAcknowledgedDeeplinkToken"

        /// Klíče, které do verze 2.3 držely nastavení timeru. Po migraci se mažou –
        /// viz `SettingsMigration`.
        enum Legacy {
            static let rounds = "rounds"
            static let isVibrating = "isVibrating"
            static let isTicking = "isTicking"
            static let isSoundEnabled = "isSoundEnabled"
            static let selectedSound = "selectedSound"
            static let selectedBackgroundIndex = "selectedBackgroundIndex"
            static let activeTimerId = "activeTimerId"
            static let startedFromDeeplink = "startedFromDeeplink"

            static let all = [
                rounds, isVibrating, isTicking, isSoundEnabled, selectedSound,
                selectedBackgroundIndex, activeTimerId, startedFromDeeplink
            ]
        }
    }
}
