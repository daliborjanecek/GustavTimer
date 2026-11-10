//
//  AppLinkRouter.swift
//  GustavTimer
//
//  Created by Dalibor Janeček on 09.11.2026.
//
//  Otevření URL z obsahu aplikace (bannery, odkazy v nastavení).
//
//  Odkaz, kterému rozumí `SharedTimerLink.route` – sdílený timer
//  (`https://gustavtraining.com/t?…`), `gustavtimerapp://whatsnew` nebo
//  obrazovka (`gustavtimerapp://settings/background`) – se nepředává
//  systému. Universal Link otevřený z vlastní aplikace by iOS poslal do
//  Safari. Jde stejnou cestou jako příchozí odkaz (`TimerView.onOpenURL`
//  → `TimerViewModel.handleDeepLink`). Ostatní URL otevře systém.
//

import UIKit
import Combine

enum AppLinkRouter {

    /// Notifikace s URL (`object`) pro `TimerView`, který drží view model.
    static let internalLinkNotification = Notification.Name("AppLinkRouter.internalLink")

    @MainActor
    static func open(_ url: URL) {
        if SharedTimerLink.route(url: url) != nil {
            NotificationCenter.default.post(name: internalLinkNotification, object: url)
        } else {
            UIApplication.shared.open(url)
        }
    }
}

/// Požadavek na otevření obrazovky v nastavení (`AppScreen`).
///
/// Nastavení je sheet nad timerem a má vlastní `NavigationStack`, takže
/// otevření má dva kroky:
///
/// 1. `TimerView` uvidí požadavek a otevře sheet nastavení (když už otevřený
///    není),
/// 2. `SettingsView` si požadavek převezme (`consume()`) při zobrazení nebo
///    hned, když je už otevřené, a obrazovku pushne do `NavigationStack`.
///
///     AppNavigator.shared.open(.background)
///
/// Volá se jen z hlavního vlákna (odkazy, klepnutí). Není `@MainActor`,
/// protože ho volá i neizolovaný `TimerViewModel`.
final class AppNavigator: ObservableObject {
    static let shared = AppNavigator()

    /// Obrazovka, kterou ještě nikdo neotevřel.
    @Published private(set) var pendingScreen: AppScreen?

    func open(_ screen: AppScreen) {
        pendingScreen = screen
    }

    /// Vrátí čekající obrazovku a požadavek smaže – otevře se jen jednou.
    func consume() -> AppScreen? {
        defer { pendingScreen = nil }
        return pendingScreen
    }
}
