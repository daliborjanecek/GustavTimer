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
    static let countdownDuration: Int = 3
    static let reviewPromptInterval: Int = 5
    
    // Odkazy
    static let reviewURL: String = "https://apps.apple.com/app/id6478176431?action=write-review"
    static let weightsURL: String = "https://apps.apple.com/us/app/gustav-weights/id6483001116"
    static let instagramURL: String = "https://www.instagram.com/gustavtraining"
    static let youtubeChallengeURL: String = "https://youtube.com/playlist?list=PLi2Zd-0ICmgIoaWudLzSF8Jt5VKAWSvdR&si=NaYIwDYMCX9rsIFW"
    static let youtubeURL: String = "https://www.youtube.com/@Gustavtraining"
    
    // Velikosti fontů
    static let largeFontSize: CGFloat = 30
    static let smallFontSize: CGFloat = 15
    
    // Maximální název intervalu
    static let maxTimerName: Int = 12
    
    // Background
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
        // v 2.0.0
        BannerImageModel(imageResource: .duckwalk, urlString: "https://youtu.be/C21zLk6bwyI"),
        BannerImageModel(imageResource: .wallsit, urlString: "https://youtu.be/zg7vFGYauh8"),
        BannerImageModel(imageResource: .mountainclimbers, urlString: "https://youtu.be/-LzQuHB1Bjs"),
        
        // update 2.2.0
        BannerImageModel(imageResource: .legraises, urlString: "https://youtu.be/4T9a8pFtgEk"),
        BannerImageModel(imageResource: .plank, urlString: "https://youtu.be/9ZVFN9BxauA"),
        BannerImageModel(imageResource: .jumplunges, urlString: "https://youtu.be/HK3M9p7xAk0")
        
    ]
    
    // Default timer
    static let defaultTimer = TimerData(order: 0, name: "Gustav Timer", rounds: -1, selectedSound: soundThemes.first ?? nil, isVibrating: false)
    
    static let soundThemes: [SoundModel] = SoundModel.allCases
    
    static let roundsOptions: [Int] = Array(1...31)
    
    static let predefinedTimers: [TimerData] = [
        // Meditation Timer
        TimerData(order: -1, name: String(localized: "PT_5MIN_MEDITATION"), rounds: -1, selectedSound: .gong, isVibrating: false, intervals: [
            IntervalData(value: 300, name: String(localized: "LAP_MEDITATION"))
        ]),
        // Tabata Timer
        TimerData(order: -2, name: String(localized: "PT_TABATA"), rounds: 8, selectedSound: .bicycle, isVibrating: true, intervals: [
            IntervalData(value: 20, name: String(localized: "LAP_WORK")),
            IntervalData(value: 10, name: String(localized: "LAP_REST"))
        ]),
        // EMOM Timer
        TimerData(order: -3, name: String(localized: "PT_EMOM_10MIN"), rounds: 10, selectedSound: .whistle, isVibrating: true, intervals: [
            IntervalData(value: 60, name: String(localized: "LAP_WORK"))
        ]),
        // HIIT trénink
        TimerData(order: -4, name: String(localized: "PT_HIIT"), rounds: 10, selectedSound: .whistle, isVibrating: true, intervals: [
            IntervalData(value: 30, name: String(localized: "LAP_SPRINT")),
            IntervalData(value: 15, name: String(localized: "LAP_REST"))
        ]),
        // AMRAP - As Many Rounds As Possible
        TimerData(order: -5, name: String(localized: "PT_AMRAP"), rounds: 20, selectedSound: .beep, isVibrating: true, intervals: [
            IntervalData(value: 60, name: String(localized: "LAP_MAX"))
        ])
    ]
    
    
}
