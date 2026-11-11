//
//  TimerEditingTests.swift
//  GustavTimerTests
//
//  Created by Dalibor Janeček on 11.11.2026.
//
//  Testuje úpravy timeru z nastavení (`TimerData+Editing`), délku tréninku
//  (`TimerSettings.roundDuration` / `totalDuration`) a ukládání pořadí
//  oblíbených.
//

import Testing
import Foundation
import SwiftData
@testable import GustavTimer

private func makeTimer(order: Int = 0, name: String = "Tabata", values: [Int] = [20, 10], rounds: Int = 8) -> TimerData {
    TimerData(
        order: order,
        name: name,
        rounds: rounds,
        selectedSound: .beep,
        isVibrating: true,
        intervals: values.map { IntervalData(value: $0, name: "I\($0)") }
    )
}

struct TimerEditingTests {

    @Test func renameLimitsLength() {
        let timer = makeTimer()
        timer.rename(to: String(repeating: "a", count: AppConfig.maxTimerTitle + 10))
        #expect(timer.name.count == AppConfig.maxTimerTitle)
    }

    @Test func addIntervalAppendsDefaultInterval() {
        let timer = makeTimer()
        #expect(timer.addInterval())
        #expect(timer.intervals.count == 3)
        #expect(timer.intervals.last?.value == AppConfig.newIntervalValue)
    }

    @Test func addIntervalStopsAtLimit() {
        let timer = makeTimer(values: Array(repeating: 10, count: AppConfig.maxTimerCount))
        #expect(!timer.canAddInterval)
        #expect(!timer.addInterval())
        #expect(timer.intervals.count == AppConfig.maxTimerCount)
    }

    @Test func removeIntervals() {
        let timer = makeTimer(values: [20, 10, 30])
        #expect(timer.removeIntervals(at: IndexSet(integer: 1)))
        #expect(timer.intervals.map(\.value) == [20, 30])
    }

    @Test func lastIntervalCannotBeRemoved() {
        let timer = makeTimer(values: [20])
        #expect(!timer.canRemoveInterval)
        #expect(!timer.removeIntervals(at: IndexSet(integer: 0)))
        #expect(timer.intervals.count == 1)
    }

    @Test func removingAllIntervalsAtOnceIsRefused() {
        let timer = makeTimer(values: [20, 10])
        #expect(!timer.removeIntervals(at: IndexSet(integersIn: 0...1)))
        #expect(timer.intervals.count == 2)
    }

    @Test func moveIntervals() {
        let timer = makeTimer(values: [20, 10, 30])
        timer.moveIntervals(from: IndexSet(integer: 0), to: 3)
        #expect(timer.intervals.map(\.value) == [10, 30, 20])
    }

    @Test func renameIntervalLimitsLength() {
        let timer = makeTimer()
        let id = timer.intervals[0].id
        timer.renameInterval(id: id, to: String(repeating: "b", count: AppConfig.maxTimerName + 5))
        #expect(timer.intervals[0].name.count == AppConfig.maxTimerName)
    }

    @Test(arguments: [(0, 1), (-5, 1), (45, 45), (99_999, AppConfig.maxTimerValue)])
    func intervalValueIsClamped(input: Int, expected: Int) {
        let timer = makeTimer()
        timer.setIntervalValue(id: timer.intervals[0].id, to: input)
        #expect(timer.intervals[0].value == expected)
    }

    @Test func unknownIntervalIsIgnored() {
        let timer = makeTimer()
        timer.renameInterval(id: UUID(), to: "X")
        timer.setIntervalValue(id: UUID(), to: 99)
        #expect(timer.intervals.map(\.value) == [20, 10])
    }
}

struct TimerDurationTests {

    @Test func roundDurationSumsIntervals() {
        #expect(makeTimer(values: [20, 10]).settings.roundDuration == 30)
    }

    @Test func totalDurationMultipliesByRounds() {
        #expect(makeTimer(values: [20, 10], rounds: 8).settings.totalDuration == 240)
    }

    /// Smyčka nekončí a jediné kolo se rovná délce kola.
    @Test(arguments: [-1, 1])
    func totalDurationIsNilWithoutMoreRounds(rounds: Int) {
        #expect(makeTimer(rounds: rounds).settings.totalDuration == nil)
    }
}

struct FavouriteOrderTests {

    /// První v seznamu dostane nejvyšší `order`, poslední 1 – nula patří
    /// hlavnímu timeru.
    @Test func reorderNumbersFromTopDown() throws {
        let container = try ModelContainer(
            for: TimerData.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let favourites = ["A", "B", "C"].enumerated().map { makeTimer(order: $0.offset + 1, name: $0.element) }
        favourites.forEach(context.insert)

        FavouriteTimers.reorder([favourites[2], favourites[0], favourites[1]], in: context)

        #expect(favourites.map(\.order) == [2, 1, 3])
        #expect(!favourites.contains { $0.order == AppConfig.mainTimerOrder })
    }
}
