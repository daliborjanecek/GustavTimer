//
//  AppLinkRouter.swift
//  GustavTimer
//
//  Created by Dalibor Janeček on 09.11.2026.
//
//  Otevření URL z obsahu aplikace (bannery, odkazy v nastavení).
//
//  Odkaz na sdílený timer (`https://gustavtraining.com/t?…`) se nepředává
//  systému – Universal Link otevřený z vlastní aplikace by iOS poslal do
//  Safari. Jde stejnou cestou jako příchozí odkaz (`TimerView.onOpenURL`
//  → `TimerViewModel.handleDeepLink`). Ostatní URL otevře systém.
//

import UIKit

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
