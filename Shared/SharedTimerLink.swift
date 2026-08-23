//
//  SharedTimerLink.swift
//  GustavTimer
//
//  Created by Dalibor Janeček on 23.08.2026.
//
//  Jediné místo, kde se sdílený odkaz na timer skládá i rozebírá.
//  Závisí pouze na Foundation – žádné UIKit/SwiftUI/SwiftData importy,
//  aby se dal použít i na Apple Watch a testovat bez běžící aplikace.
//
//  Podporované tvary odkazu (oba musí dát identický výsledek):
//
//      https://gustavtraining.com/t?Work=40&Rest=20&rounds=4&_title=THE%20COMEBACK
//      gustavtimerapp://timer?Work=40&Rest=20&rounds=4
//
//  Od verze 2.3 se generuje výhradně https varianta (Universal Link).
//  Custom schéma se dál parsuje – odkazy vygenerované verzí 2.2.1 kolují
//  mezi lidmi a musí fungovat dál.
//

import Foundation

/// Naparsovaný obsah sdíleného odkazu na timer.
///
/// Pořadí intervalů odpovídá pořadí query parametrů v URL. Duplicitní názvy
/// jsou legitimní a zachovávají se (`Squat=40&Rest=20&Pushup=40&Rest=20`),
/// proto se nikde nepracuje se slovníkem – vždy jen s polem.
struct SharedTimerLink: Equatable {

    /// Intervaly v pořadí, v jakém byly v URL.
    let intervals: [IntervalData]

    /// Počet opakování celého timeru. `-1` znamená nekonečno.
    let rounds: Int

    /// Název timeru z parametru `_title`. `nil`, pokud v odkazu nebyl.
    let title: String?
}

// MARK: - Limity

extension SharedTimerLink {

    /// Limity parsování. Výchozí hodnoty odpovídají `AppConfig`, ale drží se tady,
    /// aby byl typ nezávislý na iOS vrstvě a testovatelný s vlastními hodnotami.
    struct Limits {
        var maxIntervalCount: Int = 10
        var maxIntervalValue: Int = 600
        var maxRounds: Int = 31
        var maxTitleLength: Int = 64

        static let `default` = Limits()
    }
}

// MARK: - Klíče a jmenný prostor

extension SharedTimerLink {

    static let customScheme = "gustavtimerapp"
    static let customTimerHost = "timer"
    static let customWhatsNewHost = "whatsnew"

    /// Hostitelé, na kterých běží Universal Links. Web servíruje AASA na obou
    /// variantách (s www i bez), takže obě musí projít.
    static let webHosts = ["gustavtraining.com", "www.gustavtraining.com"]

    /// Cesta deklarovaná v AASA jako `/t` a `/t/*`.
    static let webPath = "/t"

    /// Základ pro generované odkazy.
    static let shareHost = "gustavtraining.com"

    /// Rezervovaný klíč pro počet opakování. Porovnává se case-insensitive.
    static let roundsKey = "rounds"

    /// Rezervovaný klíč pro název timeru.
    static let titleKey = "_title"

    /// Jmenný prostor rezervovaný pro budoucí parametry. Klíč začínající
    /// podtržítkem se **nikdy** neinterpretuje jako interval, takže se dají
    /// přidávat nové parametry bez kolize s uživatelskými názvy intervalů.
    static let reservedPrefix = "_"

    /// Trackovací parametry, které k odkazu přilepí sociální sítě a kampaně.
    /// Bez tohoto filtru by `utm_term=90` vytvořil interval „utm_term“ o 90 sekundách.
    static let trackingKeyPrefixes = ["utm_"]
    static let trackingKeys = ["fbclid", "gclid"]

    /// Klíč, který nesmí být použit jako název intervalu.
    static func isReservedKey(_ key: String) -> Bool {
        let lower = key.lowercased()
        if lower == roundsKey { return true }
        if trackingKeys.contains(lower) { return true }
        if trackingKeyPrefixes.contains(where: { lower.hasPrefix($0) }) { return true }
        return false
    }
}

// MARK: - Routing

extension SharedTimerLink {

    /// Cíl příchozího odkazu. Obě formy sdíleného odkazu se normalizují
    /// do jediné varianty `sharedTimer`, aby neexistovaly dvě větve,
    /// které se můžou v čase rozejít.
    enum Route: Equatable {
        case sharedTimer(items: [URLQueryItem])
        case whatsNew
    }

    /// Rozpozná příchozí URL. Vrací `nil` pro cokoliv, co aplikaci nepatří.
    static func route(url: URL) -> Route? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }

        let host = components.host?.lowercased()

        // Custom schéma – historický tvar, drží se kvůli zpětné kompatibilitě.
        if components.scheme?.lowercased() == customScheme {
            switch host {
            case customWhatsNewHost:
                return .whatsNew
            case customTimerHost:
                return .sharedTimer(items: components.queryItems ?? [])
            default:
                return nil
            }
        }

        // Universal Link – https://gustavtraining.com/t?...
        // Cesta se porovnává přesně proti tomu, co deklaruje AASA (`/t` a `/t/*`),
        // ne jen prefixem, aby se sem nechytlo `/timer` nebo `/tools`.
        if components.scheme?.lowercased() == "https",
           let host, webHosts.contains(host),
           components.path == webPath || components.path.hasPrefix(webPath + "/") {
            return .sharedTimer(items: components.queryItems ?? [])
        }

        return nil
    }
}

// MARK: - Parsování

extension SharedTimerLink {

    /// Naparsuje query parametry sdíleného odkazu.
    ///
    /// Pravidla, v pořadí, v jakém se na každý parametr aplikují:
    ///
    /// 1. Klíč `rounds` (case-insensitive) nastaví počet opakování.
    ///    `-1` = nekonečno, jinak clamp na `1...maxRounds`. Nečíselná hodnota
    ///    se ignoruje. Chybí-li parametr úplně, výsledkem je `-1`.
    /// 2. Klíč `_title` nastaví název timeru. Prázdná hodnota se ignoruje,
    ///    delší než `maxTitleLength` se ořízne. Vyhrává první výskyt.
    /// 3. Klíč začínající `_` je rezervovaný – přeskočí se, nikdy nevznikne interval.
    /// 4. Trackovací klíče (`utm_*`, `fbclid`, `gclid`) se přeskočí.
    /// 5. `název=hodnota` → pojmenovaný interval, pokud je hodnota celé číslo
    ///    v rozsahu `1...maxIntervalValue`.
    /// 6. Holé číslo bez `=` → interval pojmenovaný `„<prefix> N“`, se stejným
    ///    rozsahem. Tenhle tvar umí jen parser, generátor ho nevytváří.
    /// 7. Cokoliv jiného (`abc`, `0`, `601`, prázdná hodnota) se tiše ignoruje.
    ///
    /// Sběr intervalů se zastaví na `maxIntervalCount`, ale čtení rezervovaných
    /// klíčů pokračuje – jinak by se u desetiintervalového timeru ztratil `rounds`,
    /// který generátor zapisuje až za intervaly.
    ///
    /// - Returns: `nil`, pokud odkaz neobsahuje jediný platný interval. Volající
    ///   v takovém případě nesmí sáhnout na stávající timer.
    static func parse(
        items: [URLQueryItem],
        limits: Limits = .default,
        roundNamePrefix: String = NSLocalizedString("ROUND", comment: "")
    ) -> SharedTimerLink? {

        var intervals: [IntervalData] = []
        var rounds: Int?
        var title: String?

        for item in items {
            let key = item.name
            let lowerKey = key.lowercased()

            // 1. Počet opakování
            if lowerKey == roundsKey {
                if let value = item.value, let parsed = Int(value) {
                    rounds = parsed == -1 ? -1 : max(1, min(limits.maxRounds, parsed))
                }
                continue
            }

            // 2. + 3. Rezervovaný jmenný prostor
            if key.hasPrefix(reservedPrefix) {
                if lowerKey == titleKey, title == nil {
                    let trimmed = (item.value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        title = String(trimmed.prefix(limits.maxTitleLength))
                    }
                }
                continue
            }

            // 4. Trackovací parametry přilepené sociálními sítěmi a kampaněmi
            if isReservedKey(key) { continue }

            // Limit intervalů je vyčerpaný – dál už jen rezervované klíče výše.
            guard intervals.count < limits.maxIntervalCount else { continue }

            // 5. Plný tvar: název=hodnota
            if let value = item.value, let seconds = Int(value),
               seconds > 0, seconds <= limits.maxIntervalValue {
                intervals.append(IntervalData(value: seconds, name: key))
                continue
            }

            // 6. Minimalistický tvar: holé číslo bez hodnoty
            if item.value == nil, let seconds = Int(key),
               seconds > 0, seconds <= limits.maxIntervalValue {
                let name = "\(roundNamePrefix) \(intervals.count + 1)"
                intervals.append(IntervalData(value: seconds, name: name))
            }

            // 7. Cokoliv jiného se ignoruje.
        }

        guard !intervals.isEmpty else { return nil }

        // Chybí-li rounds v URL, výchozí hodnota je nekonečno.
        return SharedTimerLink(intervals: intervals, rounds: rounds ?? -1, title: title)
    }
}

// MARK: - Generování

extension SharedTimerLink {

    /// Znaky, které se v query smí objevit nezakódované.
    /// Oproti `urlQueryAllowed` navíc kóduje `+`, `&`, `=`, `?` a `#`, aby název
    /// intervalu nemohl rozbít strukturu odkazu a aby `+` nedorazil jako mezera.
    private static let queryAllowed: CharacterSet = {
        var set = CharacterSet.urlQueryAllowed
        set.remove(charactersIn: "+&=?#")
        return set
    }()

    /// Názvy intervalů jdou do URL jako klíče, takže se můžou srazit s rezervovaným
    /// jmenným prostorem. Kolizi řeší prefix jedné mezery: žádný znak se neztratí,
    /// v URL je z ní `%20` a na přijímací straně je prakticky neviditelná.
    ///
    ///     "rounds"  → " rounds"   (jinak by přepsal počet opakování)
    ///     "_title"  → " _title"   (jinak by se zahodil jako rezervovaný klíč)
    ///     "Work"    → "Work"
    static func escapedIntervalName(_ name: String) -> String {
        if name.hasPrefix(reservedPrefix) || isReservedKey(name) {
            return " " + name
        }
        return name
    }

    /// Sestaví sdílený odkaz.
    ///
    /// Pořadí parametrů: intervaly (v pořadí timeru) → `rounds` → `_title`.
    /// Intervalů se zapíše nejvýš `maxIntervalCount`, `rounds = -1` se zachovává
    /// jako značka nekonečna. Timer bez názvu parametr `_title` úplně vynechá,
    /// neposílá prázdnou hodnotu.
    ///
    /// - Returns: `nil`, pokud timer nemá jediný interval.
    static func url(
        intervals: [IntervalData],
        rounds: Int,
        title: String? = nil,
        limits: Limits = .default
    ) -> URL? {

        var items: [URLQueryItem] = []

        for interval in intervals.prefix(limits.maxIntervalCount) {
            guard let key = encode(escapedIntervalName(interval.name)), !key.isEmpty else { continue }
            items.append(URLQueryItem(name: key, value: String(interval.value)))
        }

        guard !items.isEmpty else { return nil }

        items.append(URLQueryItem(name: roundsKey, value: String(rounds)))

        let trimmedTitle = (title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTitle.isEmpty, let encoded = encode(String(trimmedTitle.prefix(limits.maxTitleLength))) {
            items.append(URLQueryItem(name: titleKey, value: encoded))
        }

        var components = URLComponents()
        components.scheme = "https"
        components.host = shareHost
        components.path = webPath
        components.percentEncodedQueryItems = items

        return components.url
    }

    private static func encode(_ value: String) -> String? {
        value.addingPercentEncoding(withAllowedCharacters: queryAllowed)
    }
}
