//
//  AnalyticsTests.swift
//  GustavTimerTests
//
//  Created by Dalibor Janeček on 09.11.2026.
//
//  Testuje čisté funkce, které skládají parametry signálů. Samotné odeslání
//  do TelemetryDeck se netestuje.
//

import Testing
import Foundation
@testable import GustavTimer

private func settings(
    _ values: [Int],
    rounds: Int = 8,
    sound: SoundModel? = .beep,
    isVibrating: Bool = true,
    ticking: TickingMode = .off,
    hasCountdown: Bool = true
) -> TimerSettings {
    TimerSettings(
        name: "Test",
        intervals: values.enumerated().map { IntervalData(value: $1, name: "I\($0)") },
        rounds: rounds,
        sound: sound,
        isVibrating: isVibrating,
        ticking: ticking,
        hasCountdown: hasCountdown
    )
}

// MARK: - Parametry timeru

@Test
func parametersDescribeWorkout() {
    let parameters = Analytics.parameters(for: settings([20, 10], rounds: 8, ticking: .finalSeconds))

    #expect(parameters["interval_pattern"] == "20/10")
    #expect(parameters["interval_count"] == "2")
    #expect(parameters["rounds"] == "8")
    #expect(parameters["round_seconds"] == "30")
    #expect(parameters["total_duration"] == "1-5m")
    #expect(parameters["sound"] == "beep")
    #expect(parameters["haptics"] == "true")
    #expect(parameters["ticking"] == "finalSeconds")
    #expect(parameters["countdown"] == "true")
}

@Test
func parametersForEndlessMutedTimer() {
    let parameters = Analytics.parameters(for: settings([300], rounds: -1, sound: nil, isVibrating: false))

    #expect(parameters["rounds"] == "loop")
    #expect(parameters["total_duration"] == "loop")
    #expect(parameters["sound"] == "mute")
    #expect(parameters["haptics"] == "false")
}

@Test
func intervalPatternKeepsOrder() {
    #expect(Analytics.intervalPattern(settings([45, 15, 60]).intervals) == "45/15/60")
    #expect(Analytics.intervalPattern([]) == "")
}

@Test(arguments: [
    (0.0, "<1m"), (59.9, "<1m"), (60.0, "1-5m"), (299.0, "1-5m"), (300.0, "5-15m"),
    (900.0, "15-30m"), (1800.0, "30-60m"), (3600.0, "60m+")
])
func durationBuckets(seconds: Double, bucket: String) {
    #expect(Analytics.durationBucket(seconds: seconds) == bucket)
}

@Test
func percentBucketRoundsDownAndClamps() {
    #expect(Analytics.percentBucket(0.37) == "30")
    #expect(Analytics.percentBucket(0.999) == "90")
    #expect(Analytics.percentBucket(1) == "100")
    #expect(Analytics.percentBucket(-0.2) == "0")
    #expect(Analytics.percentBucket(1.5) == "100")
}

@Test
func settingValues() {
    #expect(Analytics.settingValue("rounds", -1) == "loop")
    #expect(Analytics.settingValue("rounds", 5) == "5")
    #expect(Analytics.settingValue("haptics", false) == "false")
    #expect(Analytics.settingValue("ticking", TickingMode.everySecond) == "everySecond")
    #expect(Analytics.settingValue("interval_added", 3) == "3")
}

// MARK: - Průběh tréninku

@Test
func progressInThirdRound() {
    // Tabata 20/10 × 8 = 240 s; 3. kolo, druhý interval, zbývají 4 s → 60 + 20 + 6
    let progress = Analytics.workoutProgress(
        intervals: settings([20, 10]).intervals,
        rounds: 8, round: 3, activeIndex: 1, remainingSeconds: 4
    )
    #expect(progress.elapsed == 86)
    #expect(progress.fraction == 86.0 / 240.0)
}

@Test
func progressBeforeStartIsZero() {
    let progress = Analytics.workoutProgress(
        intervals: settings([20, 10]).intervals,
        rounds: 8, round: 0, activeIndex: 0, remainingSeconds: 20
    )
    #expect(progress.elapsed == 0)
    #expect(progress.fraction == 0)
}

@Test
func progressOfEndlessTimerHasNoFraction() {
    let progress = Analytics.workoutProgress(
        intervals: settings([300]).intervals,
        rounds: -1, round: 2, activeIndex: 0, remainingSeconds: 100
    )
    #expect(progress.elapsed == 500)
    #expect(progress.fraction == nil)
}

// MARK: - Původ timeru

@Test
func originPrefersPresetOverFavourite() {
    let tabata = settings([20, 10])
    var renamed = tabata
    renamed.name = "Moje tabata"

    let result = Analytics.origin(
        of: renamed,
        presets: [(id: "tabata", settings: tabata)],
        favourites: [renamed],
        lastLink: nil
    )
    #expect(result.origin == .preset)
    #expect(result.presetID == "tabata")
}

@Test
func originFavouriteLinkAndCustom() {
    let favourite = settings([45, 15])
    let linked = settings([30, 30])
    let custom = settings([30, 30], rounds: 3)

    #expect(Analytics.origin(of: favourite, presets: [], favourites: [favourite], lastLink: linked).origin == .favourite)
    #expect(Analytics.origin(of: linked, presets: [], favourites: [favourite], lastLink: linked).origin == .link)
    // Odkaz upravený v nastavení už je vlastní timer.
    #expect(Analytics.origin(of: custom, presets: [], favourites: [favourite], lastLink: linked).origin == .custom)
}

// MARK: - Akvizice

@Test
func acquisitionOnlyForFreshInstallWithinWindow() throws {
    let defaults = try #require(UserDefaults(suiteName: "AnalyticsTests.fresh"))
    defaults.removePersistentDomain(forName: "AnalyticsTests.fresh")
    let installed = Date(timeIntervalSince1970: 1_000_000)

    AnalyticsAcquisition.registerLaunch(defaults: defaults, now: installed)

    #expect(AnalyticsAcquisition.isEligible(defaults: defaults, now: installed.addingTimeInterval(3600)))
    #expect(!AnalyticsAcquisition.isEligible(defaults: defaults, now: installed.addingTimeInterval(25 * 3600)))
}

@Test
func acquisitionClosedForExistingUser() throws {
    let defaults = try #require(UserDefaults(suiteName: "AnalyticsTests.existing"))
    defaults.removePersistentDomain(forName: "AnalyticsTests.existing")
    defaults.set(201, forKey: AppPreferences.Key.lastOnboardingVersion)
    let now = Date(timeIntervalSince1970: 1_000_000)

    AnalyticsAcquisition.registerLaunch(defaults: defaults, now: now)

    #expect(!AnalyticsAcquisition.isEligible(defaults: defaults, now: now))
}

// MARK: - Vzdálený obsah (API)

@Test
func remoteContentSyncParametersDescribeOutcome() {
    #expect(Analytics.remoteContentSyncParameters(error: nil) == ["result": "success"])

    #expect(Analytics.remoteContentSyncParameters(error: RemoteContentError.http(status: 503, url: "x"))
        == ["result": "failed", "error": "http", "status": "503"])
    #expect(Analytics.remoteContentSyncParameters(error: RemoteContentError.unsupportedSchema(2))
        == ["result": "failed", "error": "schema"])
    #expect(Analytics.remoteContentSyncParameters(error: RemoteContentError.invalidJSON("x"))["error"] == "invalid_config")
    #expect(Analytics.remoteContentSyncParameters(error: RemoteContentError.invalidItem("x"))["error"] == "invalid_config")
    #expect(Analytics.remoteContentSyncParameters(error: RemoteContentError.tooLarge("x"))["error"] == "invalid_content")
    #expect(Analytics.remoteContentSyncParameters(error: RemoteContentError.invalidImage("x"))["error"] == "invalid_content")
    #expect(Analytics.remoteContentSyncParameters(error: URLError(.notConnectedToInternet))
        == ["result": "failed", "error": "network"])
}
