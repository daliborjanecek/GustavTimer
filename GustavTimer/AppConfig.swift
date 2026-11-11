//
//  AppConfig.swift
//  GustavTimer
//
//  Created by Dalibor Janeček on 09.09.2024.
//

import SwiftUI

struct AppConfig {
    
    static let version = 201
    static let onboardingVersion = 201
    // Maximální hodnota timeru
    static let maxTimerValue: Int = 600
    static let maxTimerCount: Int = 10
    /// Délka nově přidaného intervalu v sekundách.
    static let newIntervalValue: Int = 5
    static let countdownDuration: Int = 3
    static let reviewPromptInterval: Int = 5
    
    // Odkazy
    static let reviewURL: String = "https://apps.apple.com/app/id6478176431?action=write-review"
//    static let weightsURL: String = "https://apps.apple.com/us/app/gustav-weights/id6483001116"
//    static let instagramURL: String = "https://www.instagram.com/gustavtraining"
//    static let youtubeChallengeURL: String = "https://youtube.com/playlist?list=PLi2Zd-0ICmgIoaWudLzSF8Jt5VKAWSvdR&si=NaYIwDYMCX9rsIFW"
//    static let youtubeURL: String = "https://www.youtube.com/@Gustavtraining"
    /// Vzdáleně spravované bannery, odkazy a pozadí – viz `RemoteContentManager`.
    static let remoteContentURL = URL(string: "https://www.gustavtraining.com/wp-json/gustav-timer/v1/content")!
    /// Domény, ze kterých smí vzdálený obsah stahovat obrázky. Plugin je
    /// servíruje z `wp-content/uploads` na téže doméně. Obrázek odjinud
    /// konfiguraci zneplatní – viz `RemoteContentPolicy`.
    static let remoteContentImageHosts = ["gustavtraining.com", "www.gustavtraining.com"]

    // Velikosti fontů
    static let largeFontSize: CGFloat = 30
    static let smallFontSize: CGFloat = 15
    
    // Maximální název intervalu
    static let maxTimerName: Int = 12

    /// Maximální délka názvu timeru. Shodná s limitem `_title` ve sdíleném
    /// odkazu, aby se název neořízl při průchodu odkazem.
    static let maxTimerTitle: Int = 64
    
    // Background
    /// Pozadí, na které se přepne, když vybrané vzdálené pozadí přestane platit.
    static let defaultBackgroundIndex: Int = 0
    static let backgroundImages: [BackgroundImageModel] = [
        BackgroundImageModel(image: "Benchpress", author: "", source: "www.unsplash.com"),
        BackgroundImageModel(image: "Boxer", author: "", source: "www.unsplash.com"),
        BackgroundImageModel(image: "Ground", author: "", source: "www.unsplash.com"),
        BackgroundImageModel(image: "Lanes", author: "", source: "www.unsplash.com"),
        BackgroundImageModel(image: "Poster", author: "", source: "www.unsplash.com"),
        BackgroundImageModel(image: "Pullup", author: "", source: "www.unsplash.com"),
        BackgroundImageModel(image: "Squat", author: "", source: "www.unsplash.com"),
        BackgroundImageModel(image: "Wood", author: "", source: "www.unsplash.com"),
        BackgroundImageModel(image: "Buddha", author: "", source: "www.unsplash.com"),
        BackgroundImageModel(image: "Lotos", author: "", source: "www.unsplash.com")
    ]
    
    static let bannerName: LocalizedStringKey = "CHALLENGE"
    static let bannerImages: [BannerImageModel] = [
        // v 2.4.0
        BannerImageModel(imageResource: .gustavChallenge, urlString: "https://www.youtube.com/playlist?list=PLi2Zd-0ICmgIoaWudLzSF8Jt5VKAWSvdR")
        
    ]
    
    /// `order` hlavního (aktivního) timeru. Ostatní hodnoty: > 0 uložené
    /// oblíbené, < 0 předdefinované presety.
    static let mainTimerOrder: Int = 0

    /// Výchozí timer nové instalace. Hodnotový typ – dřív to byla jedna sdílená
    /// instance `@Model`, kterou tři různá místa vkládala do kontextu.
    static let defaultTimer: TimerSettings = .default
    
    static let soundThemes: [SoundModel] = SoundModel.allCases
    
    static let roundsOptions: [Int] = Array(1...31)

    /// Limity sdíleného odkazu odvozené z konfigurace aplikace.
    /// `SharedTimerLink` si drží vlastní výchozí hodnoty, aby nebyl závislý
    /// na iOS vrstvě – tohle je jejich jediné napojení na `AppConfig`.
    static let sharedLinkLimits = SharedTimerLink.Limits(
        maxIntervalCount: maxTimerCount,
        maxIntervalValue: maxTimerValue,
        maxRounds: roundsOptions.last ?? 31,
        maxTitleLength: maxTimerTitle
    )
}
