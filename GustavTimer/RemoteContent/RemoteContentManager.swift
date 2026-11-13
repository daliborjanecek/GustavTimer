//
//  RemoteContentManager.swift
//  GustavTimer
//
//  Created by Dalibor Janeček on 09.11.2026.
//
//  Stahuje, ukládá a poskytuje vzdálený obsah (`RemoteContent.swift`).
//
//  Zásady:
//  - Aplikace jede vždy z uložené konfigurace, síť jen na pozadí aktualizuje.
//    Žádné čekání ani loading – do doby úspěchu platí dosavadní obsah.
//  - Nová konfigurace se aktivuje, až když je ověřená a jsou stažené všechny
//    její obrázky. Selhání čehokoli = celá aktualizace se zahodí.
//  - Automaticky nejvýš jednou za 24 h od posledního úspěchu, po neúspěchu
//    při dalším otevření aplikace.
//
//  Soubory: `Application Support/RemoteContent/config.json` (původní JSON
//  z API) a `images/` (název = SHA-256 URL obrázku).
//
//      RemoteContentManager.shared.syncIfNeeded()   // při otevření aplikace
//      RemoteContentManager.shared.banners          // co zobrazit právě teď
//

import SwiftUI
import UIKit

/// Stažení dat z URL. Protokol kvůli testům.
protocol RemoteContentFetching {
    func data(from url: URL) async throws -> Data
}

struct URLSessionRemoteContentFetcher: RemoteContentFetching {
    func data(from url: URL) async throws -> Data {
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw RemoteContentError.http(status: http.statusCode, url: url.absoluteString)
        }
        return data
    }
}

/// Banner s připraveným obrázkem.
struct RemoteBannerItem: Identifiable {
    let banner: RemoteBanner
    let image: UIImage
    var id: String { banner.id }
}

/// Pozadí s připraveným obrázkem.
struct RemoteBackgroundItem: Identifiable {
    let background: RemoteBackground
    let image: UIImage
    var id: String { background.id }
}

@MainActor
final class RemoteContentManager: ObservableObject {

    static let shared = RemoteContentManager()

    /// Aktivní (uložená) konfigurace. `nil` = žádná, používá se vestavěný obsah.
    @Published private(set) var config: RemoteContentConfig?
    @Published private(set) var isSyncing = false
    /// Okamžik, ke kterému se vyhodnocuje platnost. Posouvá ho `refresh()` –
    /// při návratu do popředí a ve chvíli, kdy nějaké položce začne nebo
    /// skončí platnost. Změna překreslí views, které obsah zobrazují.
    @Published private(set) var referenceDate: Date

    let endpoint: URL
    private let directory: URL
    private let defaults: UserDefaults
    private let fetcher: RemoteContentFetching
    private let now: () -> Date
    private let language: () -> String
    /// Hlášení výsledku synchronizace do analytiky. Za chybu se předává `Error`, za úspěch `nil`.
    private let reportSync: (Error?) -> Void
    /// Verze aplikace pro `minAppVersion` / `maxAppVersion`.
    let appVersion: String
    private let imageCache = NSCache<NSString, UIImage>()
    private var refreshTask: Task<Void, Never>?

    init(
        endpoint: URL = AppConfig.remoteContentURL,
        directory: URL = RemoteContentManager.defaultDirectory,
        defaults: UserDefaults = .standard,
        fetcher: RemoteContentFetching = URLSessionRemoteContentFetcher(),
        now: @escaping () -> Date = { Date() },
        language: @escaping () -> String = { RemoteContentLanguage.current },
        reportSync: @escaping (Error?) -> Void = { Analytics.remoteContentSynced(error: $0) },
        appVersion: String = RemoteContentVersion.current
    ) {
        self.endpoint = endpoint
        self.directory = directory
        self.defaults = defaults
        self.fetcher = fetcher
        self.now = now
        self.language = language
        self.reportSync = reportSync
        self.appVersion = appVersion
        self.referenceDate = now()
        self.config = loadStoredConfig()
    }

    nonisolated static var defaultDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("RemoteContent", isDirectory: true)
    }

    private var configURL: URL { directory.appendingPathComponent("config.json") }
    private var imagesDirectory: URL { directory.appendingPathComponent("images", isDirectory: true) }

    // MARK: - Obsah k zobrazení

    var currentLanguage: String { language() }

    /// Bannery platné teď, v pořadí z API, jen s připraveným obrázkem
    /// a s odkazem, který tahle verze umí otevřít.
    var banners: [RemoteBannerItem] {
        guard let config else { return [] }
        return config.banners
            .filter { $0.isAvailable(language: currentLanguage, at: referenceDate, appVersion: appVersion) && $0.isSupported }
            .compactMap { banner in image(for: banner.imageUrl).map { RemoteBannerItem(banner: banner, image: $0) } }
    }

    /// Odkazy platné teď, v pořadí z API, jen ty, které tahle verze smí otevřít.
    var links: [RemoteLink] {
        guard let config else { return [] }
        return config.links.filter { $0.isAvailable(language: currentLanguage, at: referenceDate, appVersion: appVersion) && $0.isSupported }
    }

    /// Pozadí platná teď, v pořadí z API, jen s připraveným obrázkem.
    var backgrounds: [RemoteBackgroundItem] {
        guard let config else { return [] }
        return config.backgrounds
            .filter { $0.isAvailable(language: currentLanguage, at: referenceDate, appVersion: appVersion) }
            .compactMap { background in
                image(for: background.imageUrl).map { RemoteBackgroundItem(background: background, image: $0) }
            }
    }

    /// Obrázek vybraného vzdáleného pozadí, pokud se pořád nabízí.
    func backgroundImage(id: String) -> UIImage? {
        backgrounds.first { $0.id == id }?.image
    }

    private func image(for url: URL) -> UIImage? {
        let name = RemoteContentImageFile.name(for: url)
        if let cached = imageCache.object(forKey: name as NSString) { return cached }
        guard let image = UIImage(contentsOfFile: imagesDirectory.appendingPathComponent(name).path) else { return nil }
        imageCache.setObject(image, forKey: name as NSString)
        return image
    }

    // MARK: - Výběr pozadí

    /// Vybrané vzdálené pozadí, které se už nenabízí (skončila platnost,
    /// zmizelo z API, smazaná data), přepne na výchozí vestavěné pozadí.
    func validateBackgroundSelection() {
        guard let id = defaults.string(forKey: AppPreferences.Key.remoteBackgroundID), !id.isEmpty else { return }
        guard !backgrounds.contains(where: { $0.id == id }) else { return }
        defaults.removeObject(forKey: AppPreferences.Key.remoteBackgroundID)
        defaults.set(AppConfig.defaultBackgroundIndex, forKey: AppPreferences.Key.backgroundIndex)
    }

    /// Znovu vyhodnotí platnost položek k aktuálnímu času a naplánuje další
    /// vyhodnocení na nejbližší začátek nebo konec platnosti.
    func refresh() {
        referenceDate = now()
        validateBackgroundSelection()
        scheduleNextRefresh()
    }

    private func scheduleNextRefresh() {
        refreshTask?.cancel()
        guard let next = config?.nextAvailabilityChange(after: referenceDate) else { return }
        let delay = max(next.timeIntervalSince(now()), 1)
        refreshTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            self?.refresh()
        }
    }

    // MARK: - Synchronizace

    /// Při otevření aplikace a návratu do popředí.
    func handleBecameActive() {
        refresh()
        syncIfNeeded()
    }

    /// Spustí synchronizaci na pozadí, pokud od posledního úspěchu uběhlo 24 h.
    func syncIfNeeded() {
        guard !isSyncing, RemoteContentSyncPolicy.isSyncDue(lastSuccess: lastSuccess, now: now()) else { return }
        Task { await sync() }
    }

    /// Stáhne, ověří a aktivuje novou konfiguraci. Volá se i z debug menu
    /// (bez ohledu na 24 h).
    ///
    /// - Returns: `true`, když se nová konfigurace aktivovala.
    @discardableResult
    func sync() async -> Bool {
        guard !isSyncing else { return false }
        isSyncing = true
        defer { isSyncing = false }

        let attempt = now()
        defaults.set(attempt.timeIntervalSince1970, forKey: AppPreferences.Key.remoteContentLastAttempt)

        do {
            let data = try await fetcher.data(from: endpoint)
            guard data.count <= RemoteContentPolicy.maxConfigBytes else {
                throw RemoteContentError.tooLarge(endpoint.absoluteString)
            }
            let newConfig = try RemoteContentConfig.decode(data)
            let required = newConfig.requiredImageURLs(at: attempt)
            try await downloadMissingImages(required)

            // Teprve teď je všechno připravené – přepnout.
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: configURL, options: .atomic)
            config = newConfig
            removeImages(except: required)

            defaults.set(now().timeIntervalSince1970, forKey: AppPreferences.Key.remoteContentLastSuccess)
            recordAttempt(error: nil)
            reportSync(nil)
            refresh()
            return true
        } catch {
            recordAttempt(error: error)
            reportSync(error)
            return false
        }
    }

    /// Stáhne obrázky, které ještě nejsou uložené. Každý se zapíše atomicky,
    /// takže rozpracovaný soubor nikdy nevznikne. Co se stáhne, zůstává
    /// i při selhání dalšího obrázku – příští pokus už to nestahuje.
    private func downloadMissingImages(_ urls: [URL]) async throws {
        try FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
        for url in urls {
            let file = imagesDirectory.appendingPathComponent(RemoteContentImageFile.name(for: url))
            guard !FileManager.default.fileExists(atPath: file.path) else { continue }

            let data = try await fetcher.data(from: url)
            // Před dekódováním – obří soubor by UIImage nafoukl v paměti.
            guard data.count <= RemoteContentPolicy.maxImageBytes else {
                throw RemoteContentError.tooLarge(url.absoluteString)
            }
            guard UIImage(data: data) != nil else { throw RemoteContentError.invalidImage(url.absoluteString) }
            try data.write(to: file, options: .atomic)
        }
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var directory = directory
        try? directory.setResourceValues(values)
    }

    /// Smaže obrázky, které aktuální konfigurace nepotřebuje (i zbytky
    /// z dřívějších neúspěšných pokusů).
    private func removeImages(except urls: [URL]) {
        let keep = Set(urls.map(RemoteContentImageFile.name(for:)))
        let files = (try? FileManager.default.contentsOfDirectory(atPath: imagesDirectory.path)) ?? []
        for file in files where !keep.contains(file) {
            try? FileManager.default.removeItem(at: imagesDirectory.appendingPathComponent(file))
            imageCache.removeObject(forKey: file as NSString)
        }
    }

    private func loadStoredConfig() -> RemoteContentConfig? {
        guard let data = try? Data(contentsOf: configURL) else { return nil }
        return try? RemoteContentConfig.decode(data)
    }

    // MARK: - Diagnostika

    var lastSuccess: Date? { date(forKey: AppPreferences.Key.remoteContentLastSuccess) }
    var lastAttempt: Date? { date(forKey: AppPreferences.Key.remoteContentLastAttempt) }
    /// `nil` = zatím žádný pokus.
    var lastAttemptSucceeded: Bool? {
        defaults.object(forKey: AppPreferences.Key.remoteContentLastResult) == nil
            ? nil
            : defaults.bool(forKey: AppPreferences.Key.remoteContentLastResult)
    }
    var lastError: String? { defaults.string(forKey: AppPreferences.Key.remoteContentLastError) }
    var nextAllowedSync: Date? { RemoteContentSyncPolicy.nextAllowedSync(lastSuccess: lastSuccess) }

    private func date(forKey key: String) -> Date? {
        (defaults.object(forKey: key) as? Double).map(Date.init(timeIntervalSince1970:))
    }

    private func recordAttempt(error: Error?) {
        defaults.set(error == nil, forKey: AppPreferences.Key.remoteContentLastResult)
        if let error {
            defaults.set(error.localizedDescription, forKey: AppPreferences.Key.remoteContentLastError)
        } else {
            defaults.removeObject(forKey: AppPreferences.Key.remoteContentLastError)
        }
        objectWillChange.send()
    }

    // MARK: - Debug akce

    /// Zapomene čas posledního úspěchu – další příležitost synchronizuje.
    /// Data ani obrázky nemaže.
    func resetSyncTime() {
        defaults.removeObject(forKey: AppPreferences.Key.remoteContentLastSuccess)
        objectWillChange.send()
    }

    /// Vrátí aplikaci do stavu před první synchronizací: smaže konfiguraci
    /// i obrázky a vybrané vzdálené pozadí přepne na vestavěné. Nové
    /// stahování nespouští. Timerů ani ostatních nastavení se nedotkne.
    func clearDownloadedData() {
        try? FileManager.default.removeItem(at: directory)
        imageCache.removeAllObjects()
        config = nil
        defaults.removeObject(forKey: AppPreferences.Key.remoteContentLastSuccess)
        refresh()
    }
}
