//
//  FavouriteTimersTests.swift
//  GustavTimerTests
//
//  Created by Dalibor Janeček on 10.11.2026.
//
//  Testuje, jak se z aktivního timeru a oblíbených odvodí stav uložení.
//  Práce se SwiftData (`load`, `saveChanges`…) se netestuje.
//

import Testing
import Foundation
@testable import GustavTimer

private func timer(
    name: String = "Tabata",
    values: [Int] = [20, 10],
    rounds: Int = 8,
    sound: SoundModel? = .beep,
    isVibrating: Bool = true,
    ticking: TickingMode = .off,
    hasCountdown: Bool = true
) -> TimerSettings {
    TimerSettings(
        name: name,
        intervals: values.map { IntervalData(value: $0, name: "I\($0)") },
        rounds: rounds,
        sound: sound,
        isVibrating: isVibrating,
        ticking: ticking,
        hasCountdown: hasCountdown
    )
}

struct FavouriteTimersStatusTests {

    let favouriteID = UUID()
    let otherID = UUID()

    var favourites: [(id: UUID, settings: TimerSettings)] {
        [(favouriteID, timer()), (otherID, timer(name: "HIIT", values: [30, 15]))]
    }

    @Test func withoutSourceIsUnsaved() {
        let status = FavouriteTimers.status(main: timer(), sourceID: nil, favourites: favourites)
        #expect(status == .unsaved)
    }

    @Test func sameAsSourceIsSaved() {
        let status = FavouriteTimers.status(main: timer(), sourceID: favouriteID, favourites: favourites)
        #expect(status == .saved(favouriteID))
    }

    @Test(arguments: [
        timer(sound: .whistle),
        timer(isVibrating: false),
        timer(ticking: .everySecond),
        timer(hasCountdown: false),
        timer(name: "Tabata 2"),
        timer(values: [20, 15]),
        timer(rounds: 10)
    ])
    func anyChangeIsModified(_ main: TimerSettings) {
        let status = FavouriteTimers.status(main: main, sourceID: favouriteID, favourites: favourites)
        #expect(status == .modified(favouriteID))
    }

    @Test func deletedSourceIsUnsaved() {
        let status = FavouriteTimers.status(main: timer(), sourceID: UUID(), favourites: favourites)
        #expect(status == .unsaved)
    }

    /// Shoda s jiným oblíbeným nestačí – rozhoduje zdroj.
    @Test func matchingOtherFavouriteWithoutSourceIsUnsaved() {
        let status = FavouriteTimers.status(main: timer(), sourceID: nil, favourites: favourites)
        #expect(status == .unsaved)
    }
}

struct FavouriteTimersLegacyLinkTests {

    let favouriteID = UUID()

    @Test func linksExactMatch() {
        let id = FavouriteTimers.legacySourceID(main: timer(), favourites: [(favouriteID, timer())])
        #expect(id == favouriteID)
    }

    @Test func doesNotLinkDifferentName() {
        let id = FavouriteTimers.legacySourceID(main: timer(name: "Jiný"), favourites: [(favouriteID, timer())])
        #expect(id == nil)
    }

    @Test func doesNotLinkDifferentSound() {
        let id = FavouriteTimers.legacySourceID(main: timer(sound: nil), favourites: [(favouriteID, timer())])
        #expect(id == nil)
    }
}

struct FavouriteTimersNameTests {

    @Test func trimsWhitespace() {
        #expect(FavouriteTimers.resolvedName("  Ranní  ", fallback: "Tabata") == "Ranní")
    }

    @Test func emptyNameKeepsFallback() {
        #expect(FavouriteTimers.resolvedName("   ", fallback: "Tabata") == "Tabata")
    }

    @Test func limitsLength() {
        let long = String(repeating: "a", count: AppConfig.maxTimerTitle + 10)
        #expect(FavouriteTimers.resolvedName(long, fallback: "").count == AppConfig.maxTimerTitle)
    }
}
