//
//  SharedTimerLinkTests.swift
//  GustavTimerTests
//
//  Created by Dalibor Janeček on 23.08.2026.
//
//  Testuje jedinou parsovací cestu sdílených odkazů. `TimerViewModel.handleSharedTimer`
//  je nad tímhle typem už jen tenká obálka (zápis do SwiftData a otevření nastavení),
//  veškerá logika odkazu je tady.
//

import Testing
import Foundation
@testable import GustavTimer

// Pevný prefix místo NSLocalizedString("ROUND"), aby test nezávisel
// na jazyce, ve kterém zrovna běží.
private let roundPrefix = "ROUND"

/// Projde celou cestu: URL → route → parse. Vrací `nil`, když odkaz aplikaci nepatří
/// nebo neobsahuje jediný platný interval.
private func parse(_ string: String) -> SharedTimerLink? {
    guard let url = URL(string: string),
          case .sharedTimer(let items)? = SharedTimerLink.route(url: url) else { return nil }
    return SharedTimerLink.parse(items: items, roundNamePrefix: roundPrefix)
}

// MARK: - Obě formy odkazu

@Test("Custom schéma a https dávají identický výsledek")
func bothLinkFormsMatch() throws {
    let custom = try #require(parse("gustavtimerapp://timer?Work=40&Rest=20&rounds=4"))
    let universal = try #require(parse("https://gustavtraining.com/t?Work=40&Rest=20&rounds=4"))

    #expect(custom == universal)
    #expect(custom.intervals == [
        IntervalData(value: 40, name: "Work"),
        IntervalData(value: 20, name: "Rest")
    ])
    #expect(custom.rounds == 4)
}

@Test("Universal Link funguje i na www variantě")
func wwwHostIsAccepted() throws {
    let link = try #require(parse("https://www.gustavtraining.com/t?Work=40"))
    #expect(link.intervals.count == 1)
}

@Test("Odkaz na whatsnew se nesmí rozbít")
func whatsNewRouteSurvives() throws {
    let url = try #require(URL(string: "gustavtimerapp://whatsnew"))
    #expect(SharedTimerLink.route(url: url) == .whatsNew)
}

@Test("Cizí odkazy se ignorují", arguments: [
    "https://gustavtraining.com/timer?Work=40",  // /t není prefix /timer
    "https://gustavtraining.com/tools?Work=40",
    "https://example.com/t?Work=40",
    "gustavtimerapp://neco?Work=40"
])
func foreignLinksAreIgnored(_ string: String) throws {
    let url = try #require(URL(string: string))
    #expect(SharedTimerLink.route(url: url) == nil)
}

// MARK: - rounds

@Test("rounds=-1 znamená nekonečno")
func roundsInfinite() throws {
    #expect(try #require(parse("https://gustavtraining.com/t?Work=40&rounds=-1")).rounds == -1)
}

@Test("rounds=0 se ořízne na 1")
func roundsZeroClampsUp() throws {
    #expect(try #require(parse("https://gustavtraining.com/t?Work=40&rounds=0")).rounds == 1)
}

@Test("rounds=99 se ořízne na 31")
func roundsAboveMaxClampsDown() throws {
    #expect(try #require(parse("https://gustavtraining.com/t?Work=40&rounds=99")).rounds == 31)
}

@Test("Chybějící rounds znamená nekonečno")
func roundsMissingDefaultsToInfinite() throws {
    #expect(try #require(parse("https://gustavtraining.com/t?Work=40&Rest=20")).rounds == -1)
}

@Test("Nečíselný rounds se ignoruje a nevytvoří interval")
func roundsNonNumericIsIgnored() throws {
    let link = try #require(parse("https://gustavtraining.com/t?Work=40&rounds=abc"))
    #expect(link.rounds == -1)
    #expect(link.intervals.count == 1)
}

@Test("rounds se přečte i za desátým intervalem")
func roundsSurvivesFullIntervalList() throws {
    let intervals = (1...10).map { "L\($0)=30" }.joined(separator: "&")
    let link = try #require(parse("https://gustavtraining.com/t?\(intervals)&rounds=5"))
    #expect(link.intervals.count == 10)
    #expect(link.rounds == 5)
}

// MARK: - Intervaly

@Test("Duplicitní názvy se zachovají i s pořadím")
func duplicateNamesKeepOrder() throws {
    let link = try #require(parse("https://gustavtraining.com/t?Squat=40&Rest=20&Pushup=40&Rest=20"))

    #expect(link.intervals.count == 4)
    #expect(link.intervals.map(\.name) == ["Squat", "Rest", "Pushup", "Rest"])
    #expect(link.intervals.map(\.value) == [40, 20, 40, 20])
}

@Test("Parsování se zastaví na deseti intervalech")
func intervalLimitStopsAtTen() throws {
    let intervals = (1...15).map { "L\($0)=\($0 + 10)" }.joined(separator: "&")
    let link = try #require(parse("https://gustavtraining.com/t?\(intervals)"))

    #expect(link.intervals.count == 10)
    #expect(link.intervals.first?.name == "L1")
    #expect(link.intervals.last?.name == "L10")
}

@Test("Hodnoty mimo rozsah se zahodí", arguments: ["0", "601", "abc", "-5", ""])
func outOfRangeValuesAreDropped(_ value: String) throws {
    let link = try #require(parse("https://gustavtraining.com/t?Work=40&Bad=\(value)"))
    #expect(link.intervals == [IntervalData(value: 40, name: "Work")])
}

@Test("Hraniční hodnoty 1 a 600 projdou")
func boundaryValuesPass() throws {
    let link = try #require(parse("https://gustavtraining.com/t?A=1&B=600"))
    #expect(link.intervals.map(\.value) == [1, 600])
}

@Test("Odkaz bez platného intervalu vrátí nil")
func linkWithoutIntervalsIsNil() {
    #expect(parse("https://gustavtraining.com/t?rounds=4") == nil)
    #expect(parse("https://gustavtraining.com/t") == nil)
    #expect(parse("https://gustavtraining.com/t?_title=Prazdny") == nil)
}

// MARK: - Minimalistický tvar

@Test("Holá čísla vytvoří číslované intervaly")
func bareNumberFormat() throws {
    let link = try #require(parse("https://gustavtraining.com/t?40&20&40"))

    #expect(link.intervals.map(\.value) == [40, 20, 40])
    #expect(link.intervals.map(\.name) == ["\(roundPrefix) 1", "\(roundPrefix) 2", "\(roundPrefix) 3"])
}

@Test("Holá čísla a pojmenované intervaly se dají kombinovat")
func mixedBareAndNamedFormat() throws {
    let link = try #require(parse("https://gustavtraining.com/t?Work=40&20"))

    #expect(link.intervals.map(\.name) == ["Work", "\(roundPrefix) 2"])
    #expect(link.intervals.map(\.value) == [40, 20])
}

@Test("Holé číslo mimo rozsah se zahodí")
func bareNumberOutOfRange() throws {
    let link = try #require(parse("https://gustavtraining.com/t?40&900&0"))
    #expect(link.intervals.map(\.value) == [40])
}

// MARK: - _title

@Test("_title s mezerou i diakritikou", arguments: [
    ("THE%20COMEBACK", "THE COMEBACK"),
    ("Kruhov%C3%BD%20tr%C3%A9nink", "Kruhový trénink"),
    ("Single-arm%20row", "Single-arm row")
])
func titleDecoding(_ encoded: String, _ expected: String) throws {
    let link = try #require(parse("https://gustavtraining.com/t?Work=40&rounds=4&_title=\(encoded)"))
    #expect(link.title == expected)
    #expect(link.intervals.count == 1, "_title nesmí vzniknout jako interval")
}

@Test("Chybějící _title je nil")
func titleMissing() throws {
    #expect(try #require(parse("https://gustavtraining.com/t?Work=40")).title == nil)
}

@Test("Prázdný _title je nil")
func titleEmpty() throws {
    #expect(try #require(parse("https://gustavtraining.com/t?Work=40&_title=")).title == nil)
    #expect(try #require(parse("https://gustavtraining.com/t?Work=40&_title=%20%20")).title == nil)
}

@Test("Neznámý rezervovaný klíč se přeskočí, ne interpretuje jako interval")
func unknownReservedKeyIsSkipped() throws {
    let link = try #require(parse("https://gustavtraining.com/t?Work=40&_future=90&_v=2"))
    #expect(link.intervals == [IntervalData(value: 40, name: "Work")])
}

// MARK: - Trackovací parametry

@Test("Parametry ze sociálních sítí nevytvoří interval")
func trackingParametersCreateNoIntervals() throws {
    let link = try #require(parse(
        "https://gustavtraining.com/t?Work=40&Rest=20&rounds=4&fbclid=IwAR123&utm_term=90&utm_source=instagram&gclid=99"
    ))

    #expect(link.intervals == [
        IntervalData(value: 40, name: "Work"),
        IntervalData(value: 20, name: "Rest")
    ])
    #expect(link.rounds == 4)
}

@Test("Trackovací klíče se poznají bez ohledu na velikost písmen")
func trackingParametersAreCaseInsensitive() throws {
    let link = try #require(parse("https://gustavtraining.com/t?Work=40&UTM_TERM=90&FBCLID=7"))
    #expect(link.intervals.count == 1)
}

// MARK: - Generování

@Test("Generovaný odkaz má očekávaný tvar")
func generatedURLShape() throws {
    let url = try #require(SharedTimerLink.url(
        intervals: [
            IntervalData(value: 40, name: "Work"),
            IntervalData(value: 20, name: "Rest")
        ],
        rounds: 4,
        title: "THE COMEBACK"
    ))

    #expect(url.absoluteString == "https://gustavtraining.com/t?Work=40&Rest=20&rounds=4&_title=THE%20COMEBACK")
}

@Test("Timer bez názvu _title vůbec neposílá")
func generatedURLOmitsEmptyTitle() throws {
    let url = try #require(SharedTimerLink.url(
        intervals: [IntervalData(value: 30, name: "Work")],
        rounds: -1,
        title: "   "
    ))

    #expect(url.absoluteString == "https://gustavtraining.com/t?Work=30&rounds=-1")
    #expect(!url.absoluteString.contains("_title"))
}

@Test("Diakritika a mezery v názvech intervalů se zakódují")
func generatedURLEncodesNames() throws {
    let url = try #require(SharedTimerLink.url(
        intervals: [
            IntervalData(value: 40, name: "Single-arm row"),
            IntervalData(value: 20, name: "Kruhový trénink")
        ],
        rounds: 2,
        title: nil
    ))

    #expect(url.absoluteString.contains("Single-arm%20row=40"))
    #expect(url.absoluteString.contains("Kruhov%C3%BD%20tr%C3%A9nink=20"))
}

@Test("Generátor zapíše nejvýš deset intervalů")
func generatedURLRespectsIntervalLimit() throws {
    let intervals = (1...15).map { IntervalData(value: 30, name: "L\($0)") }
    let url = try #require(SharedTimerLink.url(intervals: intervals, rounds: 1))

    #expect(url.absoluteString.contains("L10=30"))
    #expect(!url.absoluteString.contains("L11=30"))
}

@Test("Timer bez intervalů odkaz nevytvoří")
func generatedURLNilForEmptyTimer() {
    #expect(SharedTimerLink.url(intervals: [], rounds: 4, title: "Prazdny") == nil)
}

// MARK: - Kolize s rezervovaným jmenným prostorem

@Test("Kolidující názvy intervalů se escapují mezerou", arguments: [
    ("rounds", " rounds"),
    ("Rounds", " Rounds"),
    ("_title", " _title"),
    ("utm_source", " utm_source"),
    ("Work", "Work")
])
func reservedNamesAreEscaped(_ input: String, _ expected: String) {
    #expect(SharedTimerLink.escapedIntervalName(input) == expected)
}

@Test("Interval pojmenovaný rounds nepřepíše počet kol")
func intervalNamedRoundsDoesNotClobberRounds() throws {
    let url = try #require(SharedTimerLink.url(
        intervals: [
            IntervalData(value: 40, name: "Work"),
            IntervalData(value: 15, name: "rounds")
        ],
        rounds: 4
    ))

    let link = try #require(parse(url.absoluteString))
    #expect(link.rounds == 4, "Počet kol musí zůstat 4, ne 15")
    #expect(link.intervals.count == 2)
    #expect(link.intervals.map(\.value) == [40, 15])
    // Escapování je záměrně jednosměrné – název dorazí s vedoucí mezerou.
    #expect(link.intervals[1].name == " rounds")
}

// MARK: - Round-trip

@Test("Vygenerovaný odkaz se naparsuje zpět na originál")
func roundTrip() throws {
    let intervals = [
        IntervalData(value: 40, name: "Squat"),
        IntervalData(value: 20, name: "Rest"),
        IntervalData(value: 40, name: "Pushup"),
        IntervalData(value: 20, name: "Rest")
    ]

    let url = try #require(SharedTimerLink.url(intervals: intervals, rounds: 4, title: "Kruhový trénink"))
    let link = try #require(parse(url.absoluteString))

    #expect(link.intervals == intervals)
    #expect(link.rounds == 4)
    #expect(link.title == "Kruhový trénink")
}

@Test("Round-trip zachová nekonečno")
func roundTripInfiniteRounds() throws {
    let intervals = [IntervalData(value: 300, name: "Meditace")]
    let url = try #require(SharedTimerLink.url(intervals: intervals, rounds: -1, title: nil))
    let link = try #require(parse(url.absoluteString))

    #expect(link.intervals == intervals)
    #expect(link.rounds == -1)
    #expect(link.title == nil)
}

@Test("Round-trip zvládne znaky, které by rozbily URL")
func roundTripHostileCharacters() throws {
    let intervals = [
        IntervalData(value: 30, name: "A&B"),
        IntervalData(value: 30, name: "C=D"),
        IntervalData(value: 30, name: "E+F"),
        IntervalData(value: 30, name: "G#H"),
        IntervalData(value: 30, name: "I?J")
    ]

    let url = try #require(SharedTimerLink.url(intervals: intervals, rounds: 3))
    let link = try #require(parse(url.absoluteString))

    #expect(link.intervals == intervals)
    #expect(link.rounds == 3)
}

@Test("Odkaz z verze 2.2.1 se pořád naparsuje stejně")
func legacyLinkStillWorks() throws {
    // Přesně to, co generovala 2.2.1: custom schéma, intervaly, rounds na konci.
    let link = try #require(parse("gustavtimerapp://timer?Work=30&Rest=15&rounds=8"))

    #expect(link.intervals == [
        IntervalData(value: 30, name: "Work"),
        IntervalData(value: 15, name: "Rest")
    ])
    #expect(link.rounds == 8)
    #expect(link.title == nil)
}
