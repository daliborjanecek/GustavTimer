//
//  RemoteContentTests.swift
//  GustavTimerTests
//
//  Created by Dalibor Janeček on 09.11.2026.
//
//  Dekódování a filtrování vzdáleného obsahu a synchronizace
//  `RemoteContentManager` s podvrženou sítí a dočasnou složkou.
//

import Testing
import Foundation
import UIKit
@testable import GustavTimer

// MARK: - Pomocníci

private func date(_ string: String) -> Date {
    RemoteContentDate.parse(string)!
}

private let sampleJSON = """
{
  "schemaVersion": 1,
  "generatedAt": "2026-11-09T17:30:00Z",
  "banners": [
    { "id": "banner_101", "imageUrl": "https://www.gustavtraining.com/banner-timer.jpg",
      "url": "https://gustavtraining.com/t?Work=30&Rest=15", "type": "timer", "language": "cs",
      "startAt": "2026-11-01T00:00:00Z", "endAt": "2026-12-31T23:59:59Z" },
    { "id": "banner_102", "imageUrl": "https://www.gustavtraining.com/banner-video.jpg",
      "url": "https://www.youtube.com/watch?v=EXAMPLE", "type": "youtube",
      "language": null, "startAt": null, "endAt": null }
  ],
  "links": [
    { "id": "link_201", "label": "Gustav Training", "url": "https://www.gustavtraining.com/",
      "language": null, "startAt": null, "endAt": null },
    { "id": "link_202", "label": "Workout tips", "url": "https://www.gustavtraining.com/workout-tips/",
      "language": "en", "startAt": "2026-11-15T00:00:00Z", "endAt": null }
  ],
  "backgrounds": [
    { "id": "background_301", "imageUrl": "https://www.gustavtraining.com/background-blue.jpg",
      "language": null, "startAt": null, "endAt": null },
    { "id": "background_302", "imageUrl": "https://www.gustavtraining.com/background-winter.jpg",
      "language": null, "startAt": "2026-12-01T00:00:00Z", "endAt": "2027-02-28T23:59:59Z" }
  ]
}
"""

private func json(
    banners: String = "[]",
    links: String = "[]",
    backgrounds: String = "[]",
    schemaVersion: Int = 1
) -> Data {
    Data("""
    { "schemaVersion": \(schemaVersion), "generatedAt": "2026-11-09T17:30:00Z",
      "banners": \(banners), "links": \(links), "backgrounds": \(backgrounds) }
    """.utf8)
}

private func background(_ id: String, image: String, startAt: String = "null", endAt: String = "null") -> String {
    let start = startAt == "null" ? "null" : "\"\(startAt)\""
    let end = endAt == "null" ? "null" : "\"\(endAt)\""
    return """
    { "id": "\(id)", "imageUrl": "\(image)", "language": null, "startAt": \(start), "endAt": \(end) }
    """
}

private let pngData: Data = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).pngData { context in
    UIColor.red.setFill()
    context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
}

private struct FetchFailure: Error {}

/// Podvržená síť: odpovědi podle URL, záznam všech požadavků.
private final class FakeFetcher: RemoteContentFetching {
    var responses: [URL: Data] = [:]
    var failing: Set<URL> = []
    private(set) var requests: [URL] = []

    func data(from url: URL) async throws -> Data {
        requests.append(url)
        if failing.contains(url) { throw FetchFailure() }
        guard let data = responses[url] else { throw FetchFailure() }
        return data
    }
}

/// Prostředí jednoho testu – dočasná složka a vlastní UserDefaults.
@MainActor
private final class TestEnvironment {
    let endpoint = URL(string: "https://www.gustavtraining.com/content")!
    let directory: URL
    let defaults: UserDefaults
    let fetcher = FakeFetcher()
    var now = date("2026-11-09T12:00:00Z")
    var language = "cs"

    init(_ name: String) {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("RemoteContentTests-\(name)-\(UUID().uuidString)", isDirectory: true)
        defaults = UserDefaults(suiteName: "RemoteContentTests.\(name)")!
        defaults.removePersistentDomain(forName: "RemoteContentTests.\(name)")
    }

    func makeManager() -> RemoteContentManager {
        RemoteContentManager(
            endpoint: endpoint,
            directory: directory,
            defaults: defaults,
            fetcher: fetcher,
            now: { [unowned self] in self.now },
            language: { [unowned self] in self.language }
        )
    }

    func serve(_ data: Data) { fetcher.responses[endpoint] = data }
    func serveImage(_ url: String) { fetcher.responses[URL(string: url)!] = pngData }

    var storedImages: [String] {
        let images = directory.appendingPathComponent("images")
        return ((try? FileManager.default.contentsOfDirectory(atPath: images.path)) ?? []).sorted()
    }
}

// MARK: - Dekódování

@Test
func decodesSampleConfig() throws {
    let config = try RemoteContentConfig.decode(Data(sampleJSON.utf8))

    #expect(config.schemaVersion == 1)
    #expect(config.generatedAt == date("2026-11-09T17:30:00Z"))
    #expect(config.banners.map(\.id) == ["banner_101", "banner_102"])
    #expect(config.banners[0].type == .timer)
    #expect(config.banners[0].language == "cs")
    #expect(config.banners[1].language == nil)
    #expect(config.links.map(\.label) == ["Gustav Training", "Workout tips"])
    #expect(config.backgrounds[1].endAt == date("2027-02-28T23:59:59Z"))
}

@Test
func toleratesUnknownFieldsAndBannerTypes() throws {
    let data = Data("""
    { "schemaVersion": 1, "generatedAt": "2026-11-09T17:30:00Z", "newTopLevel": { "x": 1 },
      "banners": [{ "id": "b", "imageUrl": "https://www.gustavtraining.com/b.jpg", "url": "https://www.gustavtraining.com",
                    "type": "podcast", "language": "CS-cz", "startAt": null, "endAt": null, "priority": 5 }],
      "links": [{ "id": "l", "label": "  Web  ", "url": "https://www.gustavtraining.com", "language": "",
                  "startAt": "2026-11-01T00:00:00.500Z", "endAt": null, "color": "#fff" }],
      "backgrounds": [] }
    """.utf8)

    let config = try RemoteContentConfig.decode(data)

    #expect(config.banners[0].type == nil)
    #expect(config.banners[0].language == "cs")
    #expect(config.links[0].label == "Web")
    #expect(config.links[0].language == nil)
    #expect(config.links[0].startAt != nil)
}

@Test
func bannerWithUnknownAppScreenIsNotSupported() throws {
    func banner(_ url: String) throws -> RemoteBanner {
        RemoteBanner(id: "b", imageUrl: URL(string: "https://www.gustavtraining.com/b.jpg")!,
                     url: try #require(URL(string: url)), type: .app)
    }

    #expect(try banner("gustavtimerapp://settings/background").isSupported)
    #expect(try banner("https://gustavtraining.com/t?Work=30").isSupported)
    #expect(try banner("https://apps.apple.com/app/id123").isSupported)
    // Obrazovka z novější verze administrace – klepnutí by nic neudělalo.
    #expect(try !banner("gustavtimerapp://settings/sounds").isSupported)
    #expect(try !banner("gustavtimerapp://neco").isSupported)
}

@Test
func rejectsUnsupportedSchemaVersion() {
    #expect(throws: RemoteContentError.unsupportedSchema(2)) {
        try RemoteContentConfig.decode(json(schemaVersion: 2))
    }
}

@Test
func rejectsInvalidContent() {
    // Nevalidní JSON
    #expect(throws: RemoteContentError.self) { try RemoteContentConfig.decode(Data("<html>".utf8)) }
    // Chybí povinné pole
    #expect(throws: RemoteContentError.self) {
        try RemoteContentConfig.decode(Data(#"{ "schemaVersion": 1, "banners": [], "links": [] }"#.utf8))
    }
    // Duplicitní ID
    #expect(throws: RemoteContentError.self) {
        try RemoteContentConfig.decode(json(backgrounds: "[\(background("a", image: "https://www.gustavtraining.com/1.jpg")), \(background("a", image: "https://www.gustavtraining.com/2.jpg"))]"))
    }
    // Obrázek mimo https
    #expect(throws: RemoteContentError.self) {
        try RemoteContentConfig.decode(json(backgrounds: "[\(background("a", image: "file:///etc/passwd"))]"))
    }
    // Prázdný popisek odkazu
    #expect(throws: RemoteContentError.self) {
        try RemoteContentConfig.decode(json(links: #"[{ "id": "l", "label": " ", "url": "https://www.gustavtraining.com" }]"#))
    }
}

// MARK: - Jazyk a platnost

@Test
func availabilityByLanguageAndTime() throws {
    let config = try RemoteContentConfig.decode(Data(sampleJSON.utf8))
    let timerBanner = config.banners[0]   // cs, 1. 11. – 31. 12.
    let tips = config.links[1]            // en, od 15. 11.

    #expect(timerBanner.isAvailable(language: "cs", at: date("2026-11-09T12:00:00Z")))
    #expect(!timerBanner.isAvailable(language: "en", at: date("2026-11-09T12:00:00Z")))
    #expect(!timerBanner.isAvailable(language: "cs", at: date("2026-10-31T23:59:59Z")))
    #expect(timerBanner.isAvailable(language: "cs", at: date("2026-12-31T23:59:59Z")))
    #expect(!timerBanner.isAvailable(language: "cs", at: date("2027-01-01T00:00:00Z")))

    #expect(!tips.isAvailable(language: "en", at: date("2026-11-14T23:59:59Z")))
    #expect(tips.isAvailable(language: "en", at: date("2026-11-15T00:00:00Z")))
    #expect(config.links[0].isAvailable(language: "de", at: .distantFuture))
}

@Test
func languageNormalization() {
    #expect(RemoteContentLanguage.normalize("cs") == "cs")
    #expect(RemoteContentLanguage.normalize(" EN-us ") == "en")
    #expect(RemoteContentLanguage.normalize("de_DE") == "de")
    #expect(RemoteContentLanguage.normalize("") == nil)
    #expect(RemoteContentLanguage.normalize(nil) == nil)
}

@Test
func nextAvailabilityChange() throws {
    let config = try RemoteContentConfig.decode(Data(sampleJSON.utf8))

    #expect(config.nextAvailabilityChange(after: date("2026-11-09T12:00:00Z")) == date("2026-11-15T00:00:00Z"))
    #expect(config.nextAvailabilityChange(after: date("2026-12-31T12:00:00Z")) == date("2027-01-01T00:00:00Z"))
    #expect(config.nextAvailabilityChange(after: date("2027-03-01T00:00:00Z")) == nil)
}

@Test
func requiredImagesSkipExpiredOnly() throws {
    let config = try RemoteContentConfig.decode(Data(sampleJSON.utf8))

    // Budoucí zimní pozadí se stahuje předem, jiný jazyk banneru taky.
    #expect(config.requiredImageURLs(at: date("2026-11-09T12:00:00Z")).count == 4)
    // Po konci platnosti zimního pozadí a timer banneru už nejsou potřeba.
    #expect(config.requiredImageURLs(at: date("2027-03-01T00:00:00Z")).map(\.lastPathComponent)
            == ["banner-video.jpg", "background-blue.jpg"])
}

@Test
func imageFileNameDependsOnWholeURL() {
    let v1 = RemoteContentImageFile.name(for: URL(string: "https://www.gustavtraining.com/a.jpg?v=1")!)
    let v2 = RemoteContentImageFile.name(for: URL(string: "https://www.gustavtraining.com/a.jpg?v=2")!)

    #expect(v1 != v2)
    #expect(v1.hasSuffix(".jpg"))
    #expect(!RemoteContentImageFile.name(for: URL(string: "https://www.gustavtraining.com/image")!).contains("."))
}

@Test
func syncPolicy() {
    let last = date("2026-11-09T12:00:00Z")

    #expect(RemoteContentSyncPolicy.isSyncDue(lastSuccess: nil, now: last))
    #expect(!RemoteContentSyncPolicy.isSyncDue(lastSuccess: last, now: last.addingTimeInterval(23 * 3600)))
    #expect(RemoteContentSyncPolicy.isSyncDue(lastSuccess: last, now: last.addingTimeInterval(24 * 3600)))
    // Hodiny posunuté dozadu synchronizaci nezablokují.
    #expect(RemoteContentSyncPolicy.isSyncDue(lastSuccess: last, now: last.addingTimeInterval(-3600)))
}

// MARK: - Synchronizace

@MainActor
@Test
func firstLaunchOfflineUsesBuiltInContent() async {
    let env = TestEnvironment("offline")
    let manager = env.makeManager()

    let success = await manager.sync()

    #expect(!success)
    #expect(manager.config == nil)
    #expect(manager.banners.isEmpty && manager.links.isEmpty && manager.backgrounds.isEmpty)
    #expect(manager.lastSuccess == nil)
    #expect(manager.lastAttempt == env.now)
    #expect(manager.lastAttemptSucceeded == false)
    #expect(manager.lastError != nil)
}

@MainActor
@Test
func successfulSyncActivatesConfigAndSurvivesRelaunch() async {
    let env = TestEnvironment("success")
    env.serve(Data(sampleJSON.utf8))
    ["banner-timer", "banner-video", "background-blue", "background-winter"].forEach {
        env.serveImage("https://www.gustavtraining.com/\($0).jpg")
    }
    let manager = env.makeManager()

    #expect(await manager.sync())
    #expect(manager.lastSuccess == env.now)
    #expect(manager.lastAttemptSucceeded == true)
    #expect(manager.lastError == nil)
    #expect(env.storedImages.count == 4)
    // cs, 9. 11.: oba bannery, jen odkaz bez jazyka, jen pozadí bez omezení
    #expect(manager.banners.map(\.id) == ["banner_101", "banner_102"])
    #expect(manager.links.map(\.id) == ["link_201"])
    #expect(manager.backgrounds.map(\.id) == ["background_301"])

    // Nové spuštění bez sítě načte uložený obsah.
    env.fetcher.responses = [:]
    let relaunched = env.makeManager()
    #expect(relaunched.config == manager.config)
    #expect(relaunched.banners.count == 2)
}

@MainActor
@Test
func failedImageKeepsPreviousConfig() async {
    let env = TestEnvironment("imagefail")
    env.serve(json(backgrounds: "[\(background("old", image: "https://www.gustavtraining.com/old.jpg"))]"))
    env.serveImage("https://www.gustavtraining.com/old.jpg")
    let manager = env.makeManager()
    #expect(await manager.sync())
    let lastSuccess = manager.lastSuccess

    env.now = env.now.addingTimeInterval(25 * 3600)
    env.serve(json(backgrounds: """
    [\(background("a", image: "https://www.gustavtraining.com/a.jpg")), \(background("b", image: "https://www.gustavtraining.com/b.jpg"))]
    """))
    env.serveImage("https://www.gustavtraining.com/a.jpg")
    env.fetcher.failing = [URL(string: "https://www.gustavtraining.com/b.jpg")!]

    #expect(!(await manager.sync()))
    #expect(manager.backgrounds.map(\.id) == ["old"])
    #expect(manager.lastSuccess == lastSuccess)
    #expect(manager.lastAttemptSucceeded == false)
    // Obrázek `a` se stáhl a zůstává pro příští pokus, starý taky.
    #expect(env.storedImages.count == 2)

    // Další pokus už `a` nestahuje a po úspěchu uklidí nepotřebné `old`.
    env.fetcher.failing = []
    env.serveImage("https://www.gustavtraining.com/b.jpg")
    let requestsBefore = env.fetcher.requests.count
    #expect(await manager.sync())
    #expect(env.fetcher.requests.dropFirst(requestsBefore).map(\.lastPathComponent) == ["content", "b.jpg"])
    #expect(manager.backgrounds.map(\.id) == ["a", "b"])
    #expect(env.storedImages.count == 2)
}

@MainActor
@Test
func invalidJSONKeepsPreviousConfig() async {
    let env = TestEnvironment("badjson")
    env.serve(json(links: #"[{ "id": "l", "label": "Web", "url": "https://www.gustavtraining.com" }]"#))
    let manager = env.makeManager()
    #expect(await manager.sync())

    env.serve(json(schemaVersion: 2))
    #expect(!(await manager.sync()))
    #expect(manager.links.map(\.id) == ["l"])

    env.serve(Data("{ broken".utf8))
    #expect(!(await manager.sync()))
    #expect(manager.links.map(\.id) == ["l"])
    #expect(env.makeManager().links.map(\.id) == ["l"])
}

@MainActor
@Test
func removedOrExpiredBackgroundFallsBackToDefault() async {
    let env = TestEnvironment("fallback")
    env.serve(json(backgrounds: """
    [\(background("keep", image: "https://www.gustavtraining.com/keep.jpg")),
     \(background("short", image: "https://www.gustavtraining.com/short.jpg", endAt: "2026-11-10T00:00:00Z"))]
    """))
    env.serveImage("https://www.gustavtraining.com/keep.jpg")
    env.serveImage("https://www.gustavtraining.com/short.jpg")
    let manager = env.makeManager()
    #expect(await manager.sync())

    // Vybrané pozadí s koncem platnosti – po konci (offline) přepne na index 0.
    env.defaults.set("short", forKey: AppPreferences.Key.remoteBackgroundID)
    env.defaults.set(AppConfig.defaultBackgroundIndex, forKey: AppPreferences.Key.backgroundIndex)
    manager.refresh()
    #expect(env.defaults.string(forKey: AppPreferences.Key.remoteBackgroundID) == "short")
    env.now = date("2026-11-10T00:00:01Z")
    manager.refresh()
    #expect(env.defaults.string(forKey: AppPreferences.Key.remoteBackgroundID) == nil)
    #expect(env.defaults.integer(forKey: AppPreferences.Key.backgroundIndex) == 0)

    // Pozadí odstraněné z API – po synchronizaci přepne a obrázek se smaže.
    env.defaults.set("keep", forKey: AppPreferences.Key.remoteBackgroundID)
    env.serve(json())
    #expect(await manager.sync())
    #expect(env.defaults.string(forKey: AppPreferences.Key.remoteBackgroundID) == nil)
    #expect(env.storedImages.isEmpty)
}

@MainActor
@Test
func itemStartsAndLanguageChangesOffline() async {
    let env = TestEnvironment("offlinechanges")
    env.serve(Data(sampleJSON.utf8))
    ["banner-timer", "banner-video", "background-blue", "background-winter"].forEach {
        env.serveImage("https://www.gustavtraining.com/\($0).jpg")
    }
    let manager = env.makeManager()
    #expect(await manager.sync())
    env.fetcher.responses = [:]

    env.now = date("2026-12-01T00:00:00Z")
    manager.refresh()
    #expect(manager.backgrounds.map(\.id) == ["background_301", "background_302"])

    env.language = "en"
    #expect(manager.banners.map(\.id) == ["banner_102"])
    #expect(manager.links.map(\.id) == ["link_201", "link_202"])
}

@MainActor
@Test
func debugActions() async {
    let env = TestEnvironment("debug")
    env.serve(json(backgrounds: "[\(background("bg", image: "https://www.gustavtraining.com/bg.jpg"))]"))
    env.serveImage("https://www.gustavtraining.com/bg.jpg")
    let manager = env.makeManager()
    #expect(await manager.sync())

    // Reset času: data zůstávají, synchronizace je zase na řadě.
    manager.resetSyncTime()
    #expect(manager.lastSuccess == nil)
    #expect(manager.backgrounds.count == 1)
    #expect(RemoteContentSyncPolicy.isSyncDue(lastSuccess: manager.lastSuccess, now: env.now))

    // Smazání dat: zpět na vestavěný obsah a výchozí pozadí, bez stahování.
    #expect(await manager.sync())
    env.defaults.set("bg", forKey: AppPreferences.Key.remoteBackgroundID)
    let requests = env.fetcher.requests.count
    manager.clearDownloadedData()
    #expect(manager.config == nil)
    #expect(manager.lastSuccess == nil)
    #expect(env.storedImages.isEmpty)
    #expect(env.defaults.string(forKey: AppPreferences.Key.remoteBackgroundID) == nil)
    #expect(env.defaults.integer(forKey: AppPreferences.Key.backgroundIndex) == 0)
    #expect(env.fetcher.requests.count == requests)
    #expect(env.makeManager().config == nil)
}

// MARK: - Bezpečnost

@Test
func onlySafeLinksCanBeOpened() throws {
    func url(_ string: String) throws -> URL { try #require(URL(string: string)) }

    #expect(RemoteContentPolicy.isOpenable(try url("https://www.gustavtraining.com/t?Work=30")))
    #expect(RemoteContentPolicy.isOpenable(try url("http://example.org/")))
    #expect(RemoteContentPolicy.isOpenable(try url("gustavtimerapp://settings/background")))
    #expect(RemoteContentPolicy.isOpenable(try url("gustavtimerapp://timer?Work=30")))
    // Cizí schémata by z napadeného API spouštěla jiné aplikace nebo hovory.
    #expect(!RemoteContentPolicy.isOpenable(try url("tel:+420123456789")))
    #expect(!RemoteContentPolicy.isOpenable(try url("sms:+420123456789")))
    #expect(!RemoteContentPolicy.isOpenable(try url("mailto:a@b.cz")))
    #expect(!RemoteContentPolicy.isOpenable(try url("whatsapp://send?text=x")))
    #expect(!RemoteContentPolicy.isOpenable(try url("javascript:alert(1)")))
    #expect(!RemoteContentPolicy.isOpenable(try url("https:///bez-hostu")))

    let banner = RemoteBanner(id: "b", imageUrl: try url("https://www.gustavtraining.com/b.jpg"),
                              url: try url("tel:123"), type: .web)
    #expect(!banner.isSupported)
    #expect(!RemoteLink(id: "l", label: "SMS", url: try url("sms:123")).isSupported)
    #expect(RemoteLink(id: "l", label: "Web", url: try url("https://www.gustavtraining.com/")).isSupported)
}

@MainActor
@Test
func unsafeLinksAndBannersAreHidden() async {
    let env = TestEnvironment("unsafelinks")
    env.serve(json(
        banners: """
        [{ "id": "tel", "imageUrl": "https://www.gustavtraining.com/b.jpg", "url": "tel:123", "type": "web" },
         { "id": "web", "imageUrl": "https://www.gustavtraining.com/b.jpg", "url": "https://www.gustavtraining.com/", "type": "web" }]
        """,
        links: """
        [{ "id": "sms", "label": "SMS", "url": "sms:123" },
         { "id": "web", "label": "Web", "url": "https://www.gustavtraining.com/" }]
        """
    ))
    env.serveImage("https://www.gustavtraining.com/b.jpg")
    let manager = env.makeManager()

    // Vadná položka nezablokuje celou aktualizaci, jen se nezobrazí.
    #expect(await manager.sync())
    #expect(manager.banners.map(\.id) == ["web"])
    #expect(manager.links.map(\.id) == ["web"])
}

@Test
func imagesOnlyOverHTTPSFromOwnDomain() throws {
    func url(_ string: String) throws -> URL { try #require(URL(string: string)) }

    #expect(RemoteContentPolicy.isAllowedImageURL(try url("https://www.gustavtraining.com/wp-content/uploads/a.jpg?v=1")))
    #expect(RemoteContentPolicy.isAllowedImageURL(try url("https://GustavTraining.com/a.jpg")))
    #expect(!RemoteContentPolicy.isAllowedImageURL(try url("http://www.gustavtraining.com/a.jpg")))
    #expect(!RemoteContentPolicy.isAllowedImageURL(try url("https://evil.example/a.jpg")))
    #expect(!RemoteContentPolicy.isAllowedImageURL(try url("https://gustavtraining.com.evil.example/a.jpg")))

    for image in ["https://evil.example/a.jpg", "http://www.gustavtraining.com/a.jpg"] {
        #expect(throws: RemoteContentError.self) {
            try RemoteContentConfig.decode(json(backgrounds: "[\(background("a", image: image))]"))
        }
        #expect(throws: RemoteContentError.self) {
            try RemoteContentConfig.decode(json(banners: """
            [{ "id": "b", "imageUrl": "\(image)", "url": "https://www.gustavtraining.com/", "type": "web" }]
            """))
        }
    }
}

@MainActor
@Test
func oversizedResponsesKeepPreviousConfig() async {
    let env = TestEnvironment("toolarge")
    env.serve(json(links: #"[{ "id": "l", "label": "Web", "url": "https://www.gustavtraining.com" }]"#))
    let manager = env.makeManager()
    #expect(await manager.sync())

    // Odpověď API nad limit – nedekóduje se vůbec.
    env.now = env.now.addingTimeInterval(25 * 3600)
    env.serve(Data(count: RemoteContentPolicy.maxConfigBytes + 1))
    #expect(!(await manager.sync()))
    #expect(manager.lastError == RemoteContentError.tooLarge(env.endpoint.absoluteString).errorDescription)
    #expect(manager.links.map(\.id) == ["l"])

    // Obrázek nad limit – odmítne se před dekódováním, nic se neuloží.
    env.serve(json(backgrounds: "[\(background("big", image: "https://www.gustavtraining.com/big.jpg"))]"))
    env.fetcher.responses[URL(string: "https://www.gustavtraining.com/big.jpg")!] = Data(count: RemoteContentPolicy.maxImageBytes + 1)
    #expect(!(await manager.sync()))
    #expect(manager.links.map(\.id) == ["l"])
    #expect(manager.backgrounds.isEmpty)
    #expect(env.storedImages.isEmpty)
}
