//
//  TimerShareSheet.swift
//  GustavTimer
//
//  Created by Dalibor Janeček on 03.11.2026.
//

import UIKit

/// Místo v aplikaci, odkud uživatel timer sdílí. Jde do analytiky jako `origin`.
enum TimerShareOrigin: String {
    case settings
    case favourite
    case preset
}

/// Share sheet pro odkaz na timer.
///
/// Místo SwiftUI `ShareLink` se prezentuje přímo `UIActivityViewController`,
/// protože jen ten řekne, jestli uživatel opravdu sdílel a kam. Zvolený kanál
/// se zároveň zapíše do odkazu jako `utm_source`, takže při otevření
/// u příjemce je v analytice vidět, odkud přišel.
///
///     Button("SHARE") {
///         TimerShareSheet.present(settings: timer.settings, origin: .favourite)
///     }
enum TimerShareSheet {

    /// Odkaz pro dané nastavení, `nil`, dokud timer nemá jediný interval.
    /// Podle něj se rozhoduje, jestli tlačítko sdílení vůbec ukázat.
    static func url(for settings: TimerSettings) -> URL? {
        SharedTimerLink.url(settings: settings, limits: AppConfig.sharedLinkLimits)
    }

    @MainActor
    static func present(settings: TimerSettings, origin: TimerShareOrigin) {
        guard let url = url(for: settings),
              let top = UIApplication.shared.topmostViewController else { return }

        let controller = UIActivityViewController(
            activityItems: [TimerLinkItem(url: url)],
            applicationActivities: nil
        )
        controller.completionWithItemsHandler = { activityType, completed, _, _ in
            track(settings: settings, origin: origin, activityType: activityType, completed: completed)
        }

        // Na iPadu se share sheet ukazuje jako popover a bez kotvy by spadl.
        // Tlačítko v toolbaru ani ve swipe akci UIKit view nemá, takže střed okna.
        if let popover = controller.popoverPresentationController, let view = top.view {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }

        top.present(controller, animated: true)
    }

    /// `timer.shared`, když uživatel sdílení dokončil, jinak `timer.share_cancelled`.
    /// Název timeru se posílá jen u presetů – u vlastních ho psal uživatel.
    private static func track(
        settings: TimerSettings,
        origin: TimerShareOrigin,
        activityType: UIActivity.ActivityType?,
        completed: Bool
    ) {
        var parameters = [
            "origin": origin.rawValue,
            "interval_pattern": Analytics.intervalPattern(settings.intervals)
        ]
        if completed {
            parameters["channel"] = SharedTimerLink.shareChannel(activityType: activityType?.rawValue)
        }
        if origin == .preset {
            parameters["timer_name"] = settings.name
        }

        Analytics.send(completed ? .timerShared : .shareCancelled, parameters: parameters)
    }
}

/// Dodá share sheetu odkaz označený kanálem, který si uživatel právě vybral.
/// Kanál je známý až v `itemForActivityType`, proto nestačí předat holé URL.
private final class TimerLinkItem: NSObject, UIActivityItemSource {

    let url: URL

    init(url: URL) {
        self.url = url
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        url
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any? {
        let channel = SharedTimerLink.shareChannel(activityType: activityType?.rawValue)
        return SharedTimerLink.url(url, taggedWith: channel)
    }
}

extension UIApplication {

    /// Nejvyšší prezentovaný view controller aktivního okna – nad ním se dají
    /// ukázat UIKit obrazovky i ze sheetu (Settings), který SwiftUI prezentuje samo.
    var topmostViewController: UIViewController? {
        let scene = connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        guard var top = scene?.keyWindow?.rootViewController else { return nil }
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }
}
