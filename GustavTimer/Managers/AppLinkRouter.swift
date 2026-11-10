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

/// Timer z odkazu, který čeká na potvrzení – viz
/// `TimerViewModel.pendingSharedLink`.
struct PendingSharedLink: Identifiable {
    let id = UUID()
    let url: URL
    let items: [URLQueryItem]
    let link: SharedTimerLink
    /// Z banneru v aplikaci, ne zvenku – jen pro analytiku.
    let fromApp: Bool
}

/// Dotaz „Načíst timer?“ před načtením timeru z odkazu – zvenku i z banneru.
///
/// UIKit alert nad nejvrchnějším view controllerem, ne SwiftUI `.alert`:
/// odkaz může přijít, když je otevřené nastavení nebo jiný sheet, a alert
/// připnutý k `TimerView` by se pod ním neukázal. Takhle se ukáže nad
/// čímkoli, co je zrovna nahoře, a nic se kvůli němu nezavírá.
enum SharedLinkPrompt {

    /// Právě zobrazený dotaz. Nový odkaz ho nahradí.
    private static weak var current: UIAlertController?

    /// Pořadí posledního požadavku. Starší požadavek, který ještě čeká
    /// na okno, se podle něj zahodí.
    private static var generation = 0

    /// - Parameters:
    ///   - link: timer z odkazu – do zprávy jde název a `summary`.
    ///   - onLoad: uživatel klepl na Načíst.
    ///   - onCancel: uživatel klepl na Zrušit (nebo se dotaz nepodařilo ukázat).
    @MainActor
    static func present(_ link: SharedTimerLink, onLoad: @escaping () -> Void, onCancel: @escaping () -> Void) {
        // Při studeném startu z odkazu se ještě skládá okno a případně
        // onboarding – dotaz počká, až bude kam ho ukázat.
        generation += 1
        current?.dismiss(animated: false)
        present(link, onLoad: onLoad, onCancel: onCancel, generation: generation, attempt: 0)
    }

    @MainActor
    private static func present(_ link: SharedTimerLink, onLoad: @escaping () -> Void, onCancel: @escaping () -> Void, generation request: Int, attempt: Int) {
        guard request == generation else { return }

        guard let top = UIApplication.shared.topmostViewController,
              !top.isBeingPresented, !top.isBeingDismissed else {
            guard attempt < 20 else { onCancel(); return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                present(link, onLoad: onLoad, onCancel: onCancel, generation: request, attempt: attempt + 1)
            }
            return
        }

        let details = [link.title, link.summary].compactMap { $0 }.joined(separator: "\n")
        let alert = UIAlertController(
            title: String(localized: "DEEPLINK_CONFIRM_TITLE"),
            message: String(format: String(localized: "DEEPLINK_CONFIRM_MESSAGE"), details),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: String(localized: "CANCEL"), style: .cancel) { _ in onCancel() })
        let load = UIAlertAction(title: String(localized: "DEEPLINK_CONFIRM_LOAD"), style: .default) { _ in onLoad() }
        alert.addAction(load)
        alert.preferredAction = load

        current = alert
        top.present(alert, animated: true)
    }
}
