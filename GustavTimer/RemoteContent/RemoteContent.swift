//
//  RemoteContent.swift
//  GustavTimer
//
//  Created by Dalibor Janeček on 09.11.2026.
//
//  Vzdáleně spravovaný obsah z webu gustavtraining.com – bannery, odkazy
//  v nastavení a pozadí timeru. Tady je jen model a čisté funkce (dekódování,
//  ověření, filtrování podle jazyka a platnosti). Stahování a ukládání dělá
//  `RemoteContentManager`.
//
//  Endpoint: `AppConfig.remoteContentURL`. Ukázka odpovědi:
//
//      {
//        "schemaVersion": 1,
//        "generatedAt": "2026-11-09T17:30:00Z",
//        "banners": [{ "id": "banner_101", "imageUrl": "https://…", "url": "https://…",
//                      "type": "timer", "language": "cs",
//                      "startAt": "2026-11-01T00:00:00Z", "endAt": null }],
//        "links": [{ "id": "link_201", "label": "Gustav Training", "url": "https://…",
//                    "language": null, "startAt": null, "endAt": null }],
//        "backgrounds": [{ "id": "background_301", "imageUrl": "https://…",
//                          "language": null, "startAt": null, "endAt": null }]
//      }
//
//  Kompatibilita: neznámá pole se ignorují. Jiná `schemaVersion` než
//  podporovaná znamená nekompatibilní změnu – taková konfigurace se odmítne
//  a zůstává ta uložená.
//

import Foundation
import CryptoKit

// MARK: - Model

struct RemoteContentConfig: Decodable, Equatable {
    /// Verze schématu, kterou tahle verze aplikace umí.
    static let supportedSchemaVersion = 1

    let schemaVersion: Int
    let generatedAt: Date?
    let banners: [RemoteBanner]
    let links: [RemoteLink]
    let backgrounds: [RemoteBackground]

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, generatedAt, banners, links, backgrounds
    }

    init(schemaVersion: Int, generatedAt: Date?, banners: [RemoteBanner], links: [RemoteLink], backgrounds: [RemoteBackground]) {
        self.schemaVersion = schemaVersion
        self.generatedAt = generatedAt
        self.banners = banners
        self.links = links
        self.backgrounds = backgrounds
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        // `generatedAt` je jen informativní – nečitelné datum konfiguraci neshodí.
        generatedAt = try? container.decodeIfPresent(Date.self, forKey: .generatedAt)
        banners = try container.decode([RemoteBanner].self, forKey: .banners)
        links = try container.decode([RemoteLink].self, forKey: .links)
        backgrounds = try container.decode([RemoteBackground].self, forKey: .backgrounds)
    }
}

/// Typ banneru. Určuje **jen ikonu** – otevírá se vždy `url` přes
/// `AppLinkRouter`. U typu `app` je `url` odkaz na obrazovku aplikace
/// (`gustavtimerapp://settings/background`), který web generuje z výběru
/// obrazovky v administraci. Odkazy na jiné aplikace mají typ `appstore`.
enum RemoteBannerType: String, CaseIterable {
    case timer, youtube, app, web, appstore
}

/// Společné vlastnosti položek, které se filtrují podle jazyka a platnosti.
protocol RemoteContentItem {
    var id: String { get }
    /// Dvoupísmenný kód (`cs`, `en`), `nil` = pro všechny jazyky.
    var language: String? { get }
    var startAt: Date? { get }
    var endAt: Date? { get }
    /// Nejnižší verze aplikace (včetně), `nil` = bez omezení.
    var minAppVersion: String? { get }
    /// Verze aplikace, od které už se položka nezobrazí (bez ní), `nil` = bez omezení.
    var maxAppVersion: String? { get }
}

struct RemoteBanner: RemoteContentItem, Decodable, Equatable, Identifiable {
    let id: String
    let imageUrl: URL
    let url: URL
    /// `nil` u typu, který tahle verze aplikace nezná – banner se zobrazí bez ikony.
    let type: RemoteBannerType?
    let language: String?
    let startAt: Date?
    let endAt: Date?
    let minAppVersion: String?
    let maxAppVersion: String?

    private enum CodingKeys: String, CodingKey {
        case id, imageUrl, url, type, language, startAt, endAt, minAppVersion, maxAppVersion
    }

    init(id: String, imageUrl: URL, url: URL, type: RemoteBannerType?, language: String? = nil, startAt: Date? = nil, endAt: Date? = nil,
         minAppVersion: String? = nil, maxAppVersion: String? = nil) {
        self.id = id
        self.imageUrl = imageUrl
        self.url = url
        self.type = type
        self.language = RemoteContentLanguage.normalize(language)
        self.startAt = startAt
        self.endAt = endAt
        self.minAppVersion = RemoteContentVersion.normalize(minAppVersion)
        self.maxAppVersion = RemoteContentVersion.normalize(maxAppVersion)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        imageUrl = try container.decode(URL.self, forKey: .imageUrl)
        url = try container.decode(URL.self, forKey: .url)
        type = (try container.decodeIfPresent(String.self, forKey: .type))
            .flatMap { RemoteBannerType(rawValue: $0.lowercased()) }
        language = RemoteContentLanguage.normalize(try container.decodeIfPresent(String.self, forKey: .language))
        startAt = try container.decodeIfPresent(Date.self, forKey: .startAt)
        endAt = try container.decodeIfPresent(Date.self, forKey: .endAt)
        // Nečitelný text verze položku skryje (`RemoteContentVersion.matches`),
        // jiný typ než text zneplatní konfiguraci jako u ostatních polí.
        minAppVersion = RemoteContentVersion.normalize(try container.decodeIfPresent(String.self, forKey: .minAppVersion))
        maxAppVersion = RemoteContentVersion.normalize(try container.decodeIfPresent(String.self, forKey: .maxAppVersion))
    }
}

extension RemoteBanner {
    /// Smí a umí aplikace banner otevřít? Viz `RemoteContentPolicy.isOpenable`.
    /// Jinak se banner nezobrazí.
    var isSupported: Bool { RemoteContentPolicy.isOpenable(url) }
}

struct RemoteLink: RemoteContentItem, Decodable, Equatable, Identifiable {
    let id: String
    let label: String
    let url: URL
    let language: String?
    let startAt: Date?
    let endAt: Date?
    let minAppVersion: String?
    let maxAppVersion: String?

    private enum CodingKeys: String, CodingKey {
        case id, label, url, language, startAt, endAt, minAppVersion, maxAppVersion
    }

    init(id: String, label: String, url: URL, language: String? = nil, startAt: Date? = nil, endAt: Date? = nil,
         minAppVersion: String? = nil, maxAppVersion: String? = nil) {
        self.id = id
        self.label = label
        self.url = url
        self.language = RemoteContentLanguage.normalize(language)
        self.startAt = startAt
        self.endAt = endAt
        self.minAppVersion = RemoteContentVersion.normalize(minAppVersion)
        self.maxAppVersion = RemoteContentVersion.normalize(maxAppVersion)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        label = try container.decode(String.self, forKey: .label).trimmingCharacters(in: .whitespacesAndNewlines)
        url = try container.decode(URL.self, forKey: .url)
        language = RemoteContentLanguage.normalize(try container.decodeIfPresent(String.self, forKey: .language))
        startAt = try container.decodeIfPresent(Date.self, forKey: .startAt)
        endAt = try container.decodeIfPresent(Date.self, forKey: .endAt)
        // Nečitelný text verze položku skryje (`RemoteContentVersion.matches`),
        // jiný typ než text zneplatní konfiguraci jako u ostatních polí.
        minAppVersion = RemoteContentVersion.normalize(try container.decodeIfPresent(String.self, forKey: .minAppVersion))
        maxAppVersion = RemoteContentVersion.normalize(try container.decodeIfPresent(String.self, forKey: .maxAppVersion))
    }
}

extension RemoteLink {
    /// Smí a umí aplikace odkaz otevřít? Viz `RemoteContentPolicy.isOpenable`.
    /// Jinak se odkaz nezobrazí.
    var isSupported: Bool { RemoteContentPolicy.isOpenable(url) }
}

// MARK: - Bezpečnost

/// Co aplikace z API přijme. Nespoléhá na to, že server je vždycky v pořádku:
/// ani napadený WordPress nesmí aplikací otevřít cizí URL schéma (`tel:`,
/// `sms:`, jiné aplikace), stahovat obrázky z cizích serverů (a prozradit
/// jim IP uživatelů) ani ji shodit obří odpovědí.
enum RemoteContentPolicy {

    /// Největší odpověď API. Dnešní obsah má jednotky kB.
    static let maxConfigBytes = 512 * 1024

    /// Největší obrázek banneru nebo pozadí, kontroluje se před dekódováním.
    static let maxImageBytes = 10 * 1024 * 1024

    /// Odkaz banneru nebo odkazu v nastavení, který smí aplikace otevřít:
    /// webová adresa, nebo `gustavtimerapp://`, kterému rozumí
    /// `SharedTimerLink.route` (timer, obrazovka, novinky). Odkaz na obrazovku,
    /// kterou zná až novější verze, by po klepnutí nic neudělal.
    ///
    ///     https://gustavtraining.com/t?Work=40      → true
    ///     gustavtimerapp://settings/background      → true
    ///     gustavtimerapp://settings/neznama         → false
    ///     tel:123, sms:123, whatsapp://send         → false
    static func isOpenable(_ url: URL) -> Bool {
        switch url.scheme?.lowercased() {
        case "https", "http":
            return url.host?.isEmpty == false
        case SharedTimerLink.customScheme:
            return SharedTimerLink.route(url: url) != nil
        default:
            return false
        }
    }

    /// Obrázek jen přes https z domény v `hosts`.
    static func isAllowedImageURL(_ url: URL, hosts: [String] = AppConfig.remoteContentImageHosts) -> Bool {
        guard url.scheme?.lowercased() == "https", let host = url.host?.lowercased() else { return false }
        return hosts.contains(host)
    }
}

struct RemoteBackground: RemoteContentItem, Decodable, Equatable, Identifiable {
    let id: String
    let imageUrl: URL
    let language: String?
    let startAt: Date?
    let endAt: Date?
    let minAppVersion: String?
    let maxAppVersion: String?

    private enum CodingKeys: String, CodingKey {
        case id, imageUrl, language, startAt, endAt, minAppVersion, maxAppVersion
    }

    init(id: String, imageUrl: URL, language: String? = nil, startAt: Date? = nil, endAt: Date? = nil,
         minAppVersion: String? = nil, maxAppVersion: String? = nil) {
        self.id = id
        self.imageUrl = imageUrl
        self.language = RemoteContentLanguage.normalize(language)
        self.startAt = startAt
        self.endAt = endAt
        self.minAppVersion = RemoteContentVersion.normalize(minAppVersion)
        self.maxAppVersion = RemoteContentVersion.normalize(maxAppVersion)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        imageUrl = try container.decode(URL.self, forKey: .imageUrl)
        language = RemoteContentLanguage.normalize(try container.decodeIfPresent(String.self, forKey: .language))
        startAt = try container.decodeIfPresent(Date.self, forKey: .startAt)
        endAt = try container.decodeIfPresent(Date.self, forKey: .endAt)
        // Nečitelný text verze položku skryje (`RemoteContentVersion.matches`),
        // jiný typ než text zneplatní konfiguraci jako u ostatních polí.
        minAppVersion = RemoteContentVersion.normalize(try container.decodeIfPresent(String.self, forKey: .minAppVersion))
        maxAppVersion = RemoteContentVersion.normalize(try container.decodeIfPresent(String.self, forKey: .maxAppVersion))
    }
}

// MARK: - Chyby

enum RemoteContentError: LocalizedError, Equatable {
    case unsupportedSchema(Int)
    case invalidJSON(String)
    case invalidItem(String)
    case http(status: Int, url: String)
    case invalidImage(String)
    case tooLarge(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedSchema(let version):
            return "Nepodporovaná schemaVersion \(version) (aplikace umí \(RemoteContentConfig.supportedSchemaVersion))"
        case .invalidJSON(let detail):
            return "Neplatný JSON: \(detail)"
        case .invalidItem(let detail):
            return "Neplatná položka: \(detail)"
        case .http(let status, let url):
            return "HTTP \(status): \(url)"
        case .invalidImage(let url):
            return "Soubor není obrázek: \(url)"
        case .tooLarge(let url):
            return "Příliš velký soubor: \(url)"
        }
    }
}

// MARK: - Dekódování a ověření

extension RemoteContentConfig {

    /// Dekóduje a ověří odpověď API. Při jakékoli chybě vyhodí a konfiguraci
    /// nevrátí – volající si nechá tu dosavadní.
    ///
    ///     let config = try RemoteContentConfig.decode(data)
    static func decode(_ data: Data) throws -> RemoteContentConfig {
        struct Envelope: Decodable { let schemaVersion: Int }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            guard let date = RemoteContentDate.parse(string) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Neplatné datum \(string)")
            }
            return date
        }

        // Verze se čte zvlášť, aby nová nekompatibilní struktura skončila
        // srozumitelnou chybou, ne chybou dekódování nějakého pole.
        let envelope: Envelope
        do {
            envelope = try decoder.decode(Envelope.self, from: data)
        } catch {
            throw RemoteContentError.invalidJSON(Self.describe(error))
        }
        guard envelope.schemaVersion == supportedSchemaVersion else {
            throw RemoteContentError.unsupportedSchema(envelope.schemaVersion)
        }

        let config: RemoteContentConfig
        do {
            config = try decoder.decode(RemoteContentConfig.self, from: data)
        } catch {
            throw RemoteContentError.invalidJSON(Self.describe(error))
        }
        try config.validate()
        return config
    }

    /// Kontroly, které typový systém nepokryje: prázdná a duplicitní ID,
    /// URL bez schématu, obrázek mimo https z povolené domény
    /// (`RemoteContentPolicy.isAllowedImageURL`), prázdný popisek odkazu.
    func validate() throws {
        try Self.validateIDs(banners.map(\.id), kind: "banner")
        try Self.validateIDs(links.map(\.id), kind: "link")
        try Self.validateIDs(backgrounds.map(\.id), kind: "background")

        for banner in banners {
            guard RemoteContentPolicy.isAllowedImageURL(banner.imageUrl) else { throw RemoteContentError.invalidItem("\(banner.id): imageUrl") }
            guard banner.url.scheme != nil else { throw RemoteContentError.invalidItem("\(banner.id): url") }
        }
        for link in links {
            guard !link.label.isEmpty else { throw RemoteContentError.invalidItem("\(link.id): label") }
            guard link.url.scheme != nil else { throw RemoteContentError.invalidItem("\(link.id): url") }
        }
        for background in backgrounds {
            guard RemoteContentPolicy.isAllowedImageURL(background.imageUrl) else { throw RemoteContentError.invalidItem("\(background.id): imageUrl") }
        }
    }

    private static func validateIDs(_ ids: [String], kind: String) throws {
        if ids.contains(where: { $0.trimmingCharacters(in: .whitespaces).isEmpty }) {
            throw RemoteContentError.invalidItem("\(kind) bez id")
        }
        var seen = Set<String>()
        for id in ids where !seen.insert(id).inserted {
            throw RemoteContentError.invalidItem("duplicitní id \(id)")
        }
    }

    private static func describe(_ error: Error) -> String {
        switch error {
        case DecodingError.keyNotFound(let key, let context):
            return "chybí \(Self.path(context.codingPath + [key]))"
        case DecodingError.typeMismatch(_, let context),
             DecodingError.valueNotFound(_, let context),
             DecodingError.dataCorrupted(let context):
            let path = Self.path(context.codingPath)
            return path.isEmpty ? context.debugDescription : "\(path): \(context.debugDescription)"
        default:
            return error.localizedDescription
        }
    }

    private static func path(_ codingPath: [CodingKey]) -> String {
        codingPath.map { $0.intValue.map { "[\($0)]" } ?? $0.stringValue }.joined(separator: ".")
    }
}

/// Data v API jsou v UTC ve formátu ISO 8601, volitelně s desetinami sekundy.
enum RemoteContentDate {
    static func parse(_ string: String) -> Date? {
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        if let date = plain.date(from: string) { return date }

        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: string)
    }
}

// MARK: - Jazyk a platnost

enum RemoteContentLanguage {
    /// `"CS"`, `"cs-CZ"`, `"cs_CZ"` → `"cs"`. Prázdná hodnota je `nil` (všechny jazyky).
    static func normalize(_ language: String?) -> String? {
        guard let language else { return nil }
        let code = language
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .split(whereSeparator: { $0 == "-" || $0 == "_" })
            .first
            .map(String.init)
        return code?.isEmpty == false ? code : nil
    }

    /// Jazyk, ve kterém aplikace opravdu běží (podle lokalizací v bundlu),
    /// ne preferovaný jazyk systému.
    static var current: String {
        normalize(Bundle.main.preferredLocalizations.first) ?? "en"
    }
}

/// Verze aplikace pro `minAppVersion` / `maxAppVersion`. Porovnává se po
/// číslech, chybějící část je 0 – stejně jako `gtimer_compare_versions()`
/// v pluginu:
///
///     compare("2.5", "2.5.0")   // .orderedSame
///     compare("2.5", "2.10")    // .orderedAscending
///     compare("2.x", "2.5")     // nil – nečitelná verze
enum RemoteContentVersion {

    /// Verze, ve které aplikace běží (`CFBundleShortVersionString`, např. `2.4.0`).
    static var current: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    /// Ořízne mezery, prázdná hodnota je `nil` (bez omezení).
    static func normalize(_ version: String?) -> String? {
        let trimmed = version?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Čísla verze, `nil` pro cokoli jiného než 1–4 čísla oddělená tečkou.
    static func components(_ version: String) -> [Int]? {
        let parts = version.split(separator: ".", omittingEmptySubsequences: false)
        guard (1...4).contains(parts.count) else { return nil }
        var numbers: [Int] = []
        for part in parts {
            guard !part.isEmpty, part.allSatisfy(\.isASCIIDigit), let number = Int(part) else { return nil }
            numbers.append(number)
        }
        return numbers
    }

    static func compare(_ lhs: String, _ rhs: String) -> ComparisonResult? {
        guard let a = components(lhs), let b = components(rhs) else { return nil }
        for index in 0..<max(a.count, b.count) {
            let x = index < a.count ? a[index] : 0
            let y = index < b.count ? b[index] : 0
            if x != y { return x < y ? .orderedAscending : .orderedDescending }
        }
        return .orderedSame
    }

    /// Patří `version` do rozsahu? Od `min` včetně, do `max` bez ní.
    /// Nečitelná hranice (nebo verze) položku skryje – je bezpečnější
    /// banner pro „jen novou verzi“ neukázat, než ho ukázat všem.
    static func matches(_ version: String, min: String?, max: String?) -> Bool {
        if let min {
            guard let result = compare(version, min), result != .orderedAscending else { return false }
        }
        if let max {
            guard let result = compare(version, max), result == .orderedAscending else { return false }
        }
        return true
    }
}

private extension Character {
    var isASCIIDigit: Bool { ("0"..."9").contains(self) }
}

extension RemoteContentItem {
    /// Má se položka zobrazit v jazyce `language` v okamžiku `date`
    /// ve verzi aplikace `appVersion`? Začátek i konec platnosti jsou
    /// včetně, rozsah verzí od `minAppVersion` včetně do `maxAppVersion` bez ní.
    func isAvailable(language appLanguage: String, at date: Date, appVersion: String = RemoteContentVersion.current) -> Bool {
        if let language, language != appLanguage { return false }
        if let startAt, date < startAt { return false }
        if let endAt, date > endAt { return false }
        if !RemoteContentVersion.matches(appVersion, min: minAppVersion, max: maxAppVersion) { return false }
        return true
    }

    /// Platnost už skončila – položka se nikdy znovu nezobrazí.
    func isExpired(at date: Date) -> Bool {
        if let endAt { return date > endAt }
        return false
    }
}

extension RemoteContentConfig {

    /// Obrázky, které musí být stažené, než se konfigurace aktivuje.
    /// Bez ohledu na jazyk (ten se může změnit offline) a včetně položek,
    /// jejichž platnost teprve začne. Vynechané jsou jen ty už prošlé.
    func requiredImageURLs(at date: Date) -> [URL] {
        var urls: [URL] = []
        for banner in banners where !banner.isExpired(at: date) { urls.append(banner.imageUrl) }
        for background in backgrounds where !background.isExpired(at: date) { urls.append(background.imageUrl) }
        var seen = Set<URL>()
        return urls.filter { seen.insert($0).inserted }
    }

    /// Nejbližší okamžik po `date`, kdy nějaké položce začne nebo skončí
    /// platnost. Podle něj se plánuje překreslení, ať se změna projeví
    /// i bez nové synchronizace.
    func nextAvailabilityChange(after date: Date) -> Date? {
        let items = (banners as [any RemoteContentItem])
            + (links as [any RemoteContentItem])
            + (backgrounds as [any RemoteContentItem])
        let moments = items.flatMap { item -> [Date] in
            // Konec je včetně – položka zmizí až vteřinu po něm.
            [item.startAt, item.endAt.map { $0.addingTimeInterval(1) }].compactMap { $0 }
        }
        return moments.filter { $0 > date }.min()
    }
}

// MARK: - Soubory obrázků

enum RemoteContentImageFile {
    /// Název souboru odvozený z celé URL včetně query. Web verzi obrázku
    /// mění parametrem (`?v=…`), takže nová verze dostane nový soubor
    /// a stejná URL se znovu nestahuje.
    ///
    ///     name(for: URL(string: "https://…/banner.jpg?v=1")!)  // "3f2a….jpg"
    static func name(for url: URL) -> String {
        let digest = SHA256.hash(data: Data(url.absoluteString.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        let ext = url.pathExtension.lowercased()
        let isSafeExtension = !ext.isEmpty && ext.count <= 5 && ext.allSatisfy { $0.isLetter || $0.isNumber }
        return isSafeExtension ? "\(hex).\(ext)" : hex
    }
}

// MARK: - Plán synchronizace

enum RemoteContentSyncPolicy {
    /// Minimální odstup automatických synchronizací po úspěchu.
    static let interval: TimeInterval = 24 * 60 * 60

    /// Kdy smí proběhnout další automatická synchronizace. `nil` = hned.
    static func nextAllowedSync(lastSuccess: Date?) -> Date? {
        lastSuccess.map { $0.addingTimeInterval(interval) }
    }

    /// Po neúspěchu se čas úspěchu nemění, takže se to zkusí při dalším
    /// otevření. Čas v budoucnu (posunuté hodiny) synchronizaci nezablokuje.
    static func isSyncDue(lastSuccess: Date?, now: Date) -> Bool {
        guard let lastSuccess, let next = nextAllowedSync(lastSuccess: lastSuccess) else { return true }
        return now >= next || now < lastSuccess
    }
}
