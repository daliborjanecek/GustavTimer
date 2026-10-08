# Návrh: jednotné ukládání nastavení timeru + rozšířené deeplinky

> Stav ke commitu `f39aa8f`. Dokument je **návrh k odsouhlasení**, ne hotová
> implementace – kód v ukázkách je připravený k použití, ale zatím nikde nesedí.

---

## Obsah

1. [Co je dneska kde](#1--co-je-dneska-kde)
2. [Konkrétní chyby, které z toho plynou](#2--konkrétní-chyby-které-z-toho-plynou)
3. [Návrh: jedno pravidlo rozdělení](#3--návrh-jedno-pravidlo-rozdělení)
4. [`TimerSettings` – jeden hodnotový typ](#4--timersettings--jeden-hodnotový-typ)
5. [`TimerData` jako tenký obal nad `TimerSettings`](#5--timerdata-jako-tenký-obal-nad-timersettings)
6. [`AppSettings` → `AppPreferences`](#6--appsettings--apppreferences)
7. [Aplikace nastavení do enginu](#7--aplikace-nastavení-do-enginu)
8. [Migrace ze staré verze](#8--migrace-ze-staré-verze)
9. [Deeplinky v2](#9--deeplinky-v2)
10. [Postup implementace po fázích](#10--postup-implementace-po-fázích)
11. [Testy](#11--testy)
12. [Nálezy mimo zadání](#12--nálezy-mimo-zadání)

---

## 1 · Co je dneska kde

Tabulka je klíč k celému dokumentu. Sloupec **„kdo to čte při běhu"** je to
podstatné – ukazuje, která kopie je skutečný zdroj pravdy.

| Nastavení | SwiftData `TimerData` | UserDefaults | Kdo to čte při běhu | Přežije uložení do oblíbených? | Jde přes odkaz? |
|---|---|---|---|---|---|
| intervaly | `intervals` | – | `TimerEngine` | ✅ | ✅ |
| kola | `rounds` | `"rounds"` | **UserDefaults** | ✅ | ✅ |
| zvuk | `selectedSound` | `"isSoundEnabled"` | **obojí** (výběr z DB, zapnutí z UD) | ✅ | ❌ |
| vibrace | `isVibrating` | `"isVibrating"` | **UserDefaults** | ✅ | ❌ |
| tikání | **chybí** | `"isTicking"` | UserDefaults | ❌ | ❌ |
| odpočet 3-2-1 | `hasCountdown` | – | SwiftData | ❌ (viz níže) | ❌ |
| název | `name` | – | UI | ✅ | ✅ |
| pozadí | – | `"bgIndex"` | UserDefaults | – | ❌ |
| formát času | – | `"timeDisplayFormat"` | UserDefaults | – | ❌ |

Zdroj pravdy je tedy rozstřelený na tři místa a u zvuku dokonce na dvě naráz.
`TimerData.rounds` a `TimerData.isVibrating` existují, ale při běhu timeru se
**nikdy nečtou** – `TimerViewModel` sahá do `@AppStorage`. Zapisuje je jen
`FavouritesView.selectTimer`, takže obsahují to, co tam někdy dávno spadlo při
výběru oblíbeného.

### Kde se to rozpadá v kódu

`TimerViewModel.loadTimers()` (`GustavTimer/Views/Timer/TimerViewModel.swift:345`)
aplikuje z databáze **jen dvě věci**:

```swift
engine.loadIntervals(timerData.intervals, resetState: resetCurrentState)
engine.hasCountdown = timerData.hasCountdown
// rounds, selectedSound, isVibrating, isTicking – nic
```

Všechno ostatní si `TimerViewModel` bere z `@AppStorage`
(`TimerViewModel.swift:50`, `57–59`) a `rounds` navíc synchronizuje do enginu přes
odposlech `UserDefaults.didChangeNotification` (`TimerViewModel.swift:105–113`) –
to je obcházka, která existuje jen proto, že `rounds` žije mimo model.

---

## 2 · Konkrétní chyby, které z toho plynou

Tohle nejsou hypotézy, každou jde reprodukovat.

### 2.1 Tikání se neuloží do oblíbených ani nepřenese

`isTicking` v `TimerData` vůbec není. Uložím si timer s tikáním, vyberu jiný,
vrátím se k němu – tikání je takové, jaké zrovna bylo v UserDefaults. Je to
globální přepínač, který se tváří jako nastavení timeru.

### 2.2 Odpočet 3-2-1 se ztratí při uložení i při výběru

`SettingsView.saveTimer()` (`SettingsView.swift:339`) i
`FavouritesView.saveTimer()` (`FavouritesView.swift:173`) staví nový `TimerData`
a ručně kopírují `intervals` a `selectedSound`. `hasCountdown` **nekopírují**,
takže nový oblíbený vždycky dostane default `true`.

`selectTimer()` v obou souborech kopíruje `name`, `intervals`, `selectedSound`,
`isVibrating` (a ve `FavouritesView` navíc `rounds`) – `hasCountdown` zase ne.
Vyberu oblíbený s vypnutým odpočtem, odpočet zůstane zapnutý.

### 2.3 Dvě různé implementace téže operace

| | `SettingsView.selectTimer` | `FavouritesView.selectTimer` |
|---|---|---|
| kopíruje `rounds` | ❌ | ✅ |
| volá `context.save()` | ❌ | ✅ |
| kopíruje `hasCountdown` | ❌ | ❌ |

Stejná akce, dvě těla, dvě různá chování. `SearchTabView` má třetí kopii.

### 2.4 `TimerData.rounds` hlavního timeru je zastaralý

Přepínač kol v `SettingsView` je navázaný na `appSettings.rounds`
(`SettingsView.swift:146`), tedy na UserDefaults. Do `TimerData(order: 0).rounds`
se nezapíše nic. Kdyby se dneska nabídlo sdílení aktivního timeru (což je
logický další krok), odešle se v odkazu stará hodnota kol.

### 2.5 Zvuk má dvě reprezentace téhož

`selectedSound: SoundModel?` (nil = ticho) a `isSoundEnabled: Bool` říkají to
samé. Drží se v synchronizaci ručně na třech místech
(`AppSettings.save(from:)`, `TimerViewModel.setSound`, `SoundSettingsView`
toggle). Jedna z těch cest se dřív nebo později rozejde.

### 2.6 Deeplink nese jen intervaly, kola a název

`handleSharedTimer` (`TimerViewModel.swift:322`) nastaví `timers`, `rounds`
a jméno. Zvuk, vibrace, tikání a odpočet zůstanou moje. Sdílená Tabata tedy
u příjemce nezní tak, jak ji odesílatel poslal – což je u sdílení tréninku dost
podstatná část zážitku.

### 2.7 Mrtvé klíče v UserDefaults

`ContentView.swift:28–31` deklaruje `selectedBackgroundIndex`, `activeTimerId`,
`selectedSound` a `isSoundEnabled` – ani jeden se v těle view nepoužívá.
Dokumentace navíc zmiňuje `startedFromDeeplink`, který už v kódu není.

---

## 3 · Návrh: jedno pravidlo rozdělení

> **Co definuje timer, patří do SwiftData. Co patří zařízení, zůstává
> v UserDefaults.**

Test: *„Kdyby mi tenhle trénink někdo poslal odkazem, chci, aby mi přišel i tenhle
přepínač?"* Ano → `TimerData`. Ne → UserDefaults.

**Do `TimerData` (nastavení timeru):**
`name`, `intervals`, `rounds`, `selectedSound`, `isVibrating`, **`isTicking`** (nové),
`hasCountdown`

**V UserDefaults (nastavení zařízení):**
`bgIndex` (pozadí je vizuál aplikace, ne vlastnost tréninku),
`timeDisplayFormat`, `lastSelectedSound` (pamatuje si poslední zvuk pro toggle
ztlumení), počítadla `completedTimerCount`, `stopCounter`, `whatsNewVersion`,
`lastOnboardingVersion`, a předávací tokeny deeplinku.

**Ke smazání:**
`rounds`, `isVibrating`, `isTicking`, `isSoundEnabled`, `selectedSound`,
`selectedBackgroundIndex`, `activeTimerId`.

`isSoundEnabled` mizí úplně – `selectedSound == nil` znamená ticho a je to
jediná definice. Aby `SoundSettingsView` pořád uměl toggle „vypnout / zase
zapnout ten samý zvuk", poslední vybraný zvuk se odloží do
`@AppStorage("lastSelectedSound")`. To je správně nastavení zařízení: *„jaký
zvuk mám rád"*, ne *„jak zní tenhle trénink"*. Dnes je to jen `@State`, takže se
ztratí při odchodu z obrazovky.

---

## 4 · `TimerSettings` – jeden hodnotový typ

Nový soubor `Shared/TimerSettings.swift`. Čistý `struct` bez SwiftData
a SwiftUI – testovatelný, `Codable` (tedy použitelný i pro WatchConnectivity)
a je to **jediná definice toho, co je timer**.

```swift
//
//  TimerSettings.swift
//  GustavTimer
//
//  Kompletní nastavení jednoho timeru jako hodnotový typ.
//  Závisí pouze na Foundation – žádné SwiftData, SwiftUI ani UIKit,
//  aby se dal použít na Watch, v testech i při skládání sdíleného odkazu.
//
//  Tohle je jediné místo, kde je napsané, co všechno „timer" obnáší.
//  Přidání dalšího nastavení = jedno pole tady; kompilátor pak ukáže
//  všechna místa, která se musí dopsat (persistence, odkaz, engine).
//

import Foundation

struct TimerSettings: Equatable, Codable, Sendable {

    /// Název timeru, max `AppConfig.maxTimerName` znaků (limit vynucuje UI).
    var name: String

    /// Intervaly v pořadí jednoho kola.
    var intervals: [IntervalData]

    /// Počet opakování celého kola. `-1` = nekonečno.
    var rounds: Int

    /// Zvuk přechodu mezi intervaly. `nil` = ztlumeno.
    /// Tohle je jediná reprezentace „zvuk zapnutý/vypnutý" – žádný
    /// samostatný `isSoundEnabled` už neexistuje.
    var sound: SoundModel?

    /// Haptická odezva při přechodu intervalu a konci kola.
    var isVibrating: Bool

    /// Tikání každou uplynulou sekundu.
    var isTicking: Bool

    /// Odpočet 3-2-1 před prvním kolem.
    var hasCountdown: Bool

    static let `default` = TimerSettings(
        name: "Gustav Timer",
        intervals: [
            IntervalData(value: 60, name: "Work"),
            IntervalData(value: 30, name: "Rest")
        ],
        rounds: -1,
        sound: .beep,
        isVibrating: false,
        isTicking: false,
        hasCountdown: true
    )

    /// Shoda „je to tentýž trénink" – ignoruje název.
    ///
    /// Používá se pro hvězdičku „už uloženo" v toolbaru a pro zvýraznění
    /// vybraného timeru v oblíbených. Název se schválně vynechává: po uložení
    /// mezi oblíbené dostane záznam jméno od uživatele, ale jde pořád o tentýž
    /// trénink.
    func matchesWorkout(of other: TimerSettings) -> Bool {
        var lhs = self, rhs = other
        lhs.name = ""; rhs.name = ""
        return lhs == rhs
    }
}
```

Praktický důsledek: až budeš příště přidávat další přepínač (třeba „hlasové
odpočítávání"), dopíšeš jedno pole sem a **kompilátor tě dovede** na persistenci,
generátor odkazu, parser i engine. Dneska se na takové místo přijde až tím, že
uživateli něco nesedí.

---

## 5 · `TimerData` jako tenký obal nad `TimerSettings`

`TimerData` zůstává `@Model` (persistence, `order`, statistiky), ale nastavení
už neřeší po jednom poli.

```swift
@Model
class TimerData {

    var id: UUID = UUID()
    var order: Int

    // --- nastavení timeru ---
    var name: String
    var intervals: [IntervalData] = []
    var rounds: Int
    var selectedSound: SoundModel?
    var isVibrating: Bool
    var isTicking: Bool = false      // NOVÉ – default kvůli lightweight migraci
    var hasCountdown: Bool = true

    // --- statistiky ---
    var createdAt: Date = Date()
    var usedCount: Int = 0
    var lastUsed: Date? = nil
}

extension TimerData {

    /// Celé nastavení timeru jedním čtením/zápisem.
    /// Díky tomuhle neexistuje jediné místo, které kopíruje nastavení „po polích" –
    /// právě takové místo je dneska zdrojem chyb 2.1–2.3.
    var settings: TimerSettings {
        get {
            TimerSettings(
                name: name,
                intervals: intervals,
                rounds: rounds,
                sound: selectedSound,
                isVibrating: isVibrating,
                isTicking: isTicking,
                hasCountdown: hasCountdown
            )
        }
        set {
            name = newValue.name
            intervals = newValue.intervals
            rounds = newValue.rounds
            selectedSound = newValue.sound
            isVibrating = newValue.isVibrating
            isTicking = newValue.isTicking
            hasCountdown = newValue.hasCountdown
        }
    }

    convenience init(order: Int, settings: TimerSettings) {
        self.init(
            order: order,
            name: settings.name,
            rounds: settings.rounds,
            selectedSound: settings.sound,
            isVibrating: settings.isVibrating,
            intervals: settings.intervals
        )
        self.isTicking = settings.isTicking
        self.hasCountdown = settings.hasCountdown
    }
}
```

### Co se tím smrskne

`selectTimer` ve třech souborech:

```swift
// PŘED (SettingsView.swift:391)
mainTimer.name = timer.name
mainTimer.intervals = timer.intervals
mainTimer.selectedSound = timer.selectedSound
mainTimer.isVibrating = timer.isVibrating
appSettings.save(from: timer)
// rounds a hasCountdown se zapomněly, context.save() chybí

// PO
mainTimer.settings = timer.settings
try? context.save()
```

`saveTimer` ve dvou souborech:

```swift
// PŘED (SettingsView.swift:339)
let newTimer = TimerData(order: newOrder, name: newTimerName,
                         rounds: appSettings.rounds, isVibrating: appSettings.isVibrating)
newTimer.intervals = mainTimer.intervals
newTimer.selectedSound = mainTimer.selectedSound
context.insert(newTimer)

// PO
var settings = mainTimer.settings
settings.name = newTimerName
context.insert(TimerData(order: newOrder, settings: settings))
mainTimer.name = newTimerName   // aktivní timer převezme pojmenování
```

### Rovnost `TimerData`

Dneska `==` porovnává **jen intervaly** (`TimerData.swift:48`), takže dva timery
se stejnými intervaly a jiným zvukem jsou „shodné". Až budou všechna nastavení
součástí timeru, dává smysl porovnávat všechna. Navrhuju `==` úplně zrušit
a call-sites přepsat na pojmenovanou metodu, aby bylo z místa volání vidět, co
se vlastně porovnává:

```swift
// SettingsView.isTimerAlreadySaved / isTimerSelected
savedTimers.contains { $0.settings.matchesWorkout(of: mainTimer.settings) }
```

> ⚠️ **Změna chování k ověření:** hvězdička „už uloženo" a zvýraznění vybraného
> timeru teď budou reagovat i na změnu zvuku/vibrací/tikání, ne jen intervalů.
> Myslím, že je to správně (změním zvuk → už to není ten uložený trénink), ale
> je to viditelná změna, tak ať není překvapením.

---

## 6 · `AppSettings` → `AppPreferences`

`AppSettings` po přesunu nastavení zbude prázdná skořápka. Navrhuju ji
přejmenovat, aby název říkal, co v ní je, a zavést enum klíčů (dneska jsou
řetězce roztroušené v šesti souborech, `"isSoundEnabled"` je napsané na čtyřech
místech).

```swift
/// Nastavení **zařízení**, ne timeru. Co patří timeru, žije v TimerData.
/// Viz GustavTimer-Navrh-Nastaveni-A-Deeplinku.md, kapitola 3.
final class AppPreferences: ObservableObject {
    @AppStorage(Key.background) var backgroundIndex: Int = 0
    @AppStorage(Key.timeDisplayFormat) var timeDisplayFormat: TimeDisplayFormat = .seconds

    /// Poslední vybraný zvuk – aby toggle „ztlumit / zase zapnout"
    /// v SoundSettingsView vrátil ten samý zvuk i po odchodu z obrazovky.
    @AppStorage(Key.lastSelectedSound) var lastSelectedSound: SoundModel = .beep

    enum Key {
        static let background = "bgIndex"
        static let timeDisplayFormat = "timeDisplayFormat"
        static let lastSelectedSound = "lastSelectedSound"
        static let completedTimerCount = "completedTimerCount"
        static let stopCounter = "stopCounter"
        static let whatsNewVersion = "whatsNewVersion"
        static let lastOnboardingVersion = "lastOnboardingVersion"
    }
}
```

> ⚠️ Dneska se `AppSettings()` vytváří jako `@ObservedObject var appSettings = AppSettings()`
> ve `FavouritesView` a `SearchTabView`. `@ObservedObject` s inicializací přímo
> v deklaraci si SwiftUI nedrží – objekt vzniká znovu při každém překreslení.
> Funguje to jen proto, že za tím stojí UserDefaults. Při přepisu použij
> `@StateObject`, nebo ještě líp jednu instanci přes `.environmentObject`.

---

## 7 · Aplikace nastavení do enginu

Jedna metoda, jeden směr toku dat: `TimerData → TimerSettings → engine + VM`.

```swift
// TimerViewModel

/// Nastavení aktivního timeru. Jediné místo, kde se nastavení dostává do enginu.
@Published private(set) var settings: TimerSettings = .default

private func apply(_ new: TimerSettings, resetState: Bool) {
    settings = new
    engine.loadIntervals(new.intervals, resetState: resetState)
    engine.rounds = new.rounds
    engine.hasCountdown = new.hasCountdown
    // zvuk, vibrace a tikání čte zpětná vazba přímo ze `settings`
}
```

a `loadTimers` z toho udělá jednořádek:

```swift
if let timerData = timerDataArray.first {
    apply(timerData.settings, resetState: resetCurrentState)
} else {
    createAndSaveDefaultTimers()
}
```

**Co tím zmizí:**

- `@AppStorage("rounds" / "isVibrating" / "isTicking" / "isSoundEnabled")`
  z `TimerViewModel` (`TimerViewModel.swift:50`, `57–59`)
- celý odposlech `UserDefaults.didChangeNotification` pro `rounds`
  (`TimerViewModel.swift:105–113`) – obcházka, která existuje jen kvůli
  rozdělenému úložišti
- `syncRoundsToEngine()`
- `setSound(sound:)` a jeho dvě volání v `TimerView`
  (`TimerView.swift:44` a `:297`) – `reloadTimers()` teď nastaví všechno

**Poznámka ke zpětné vazbě.** Dnešní `playSound()` má tuhle větev:

```swift
guard isSoundEnabled else { playTickSound(); return }
```

Tedy: při ztlumeném zvuku se na přechodu intervalu přehraje tik. Není to
překlep – `TimerEngine.tick()` pošle `.secondTick` jen když `remainingTime > 0`,
takže na poslední sekundě intervalu přijde `.intervalTransition` a tik by jinak
vypadl. Při přepisu to zachovej, ale napiš to explicitně, ať to příště nikdo
nesmaže jako podivnost:

```swift
private func playSound() {
    if let sound = settings.sound {
        SoundManager.instance.playSound(soundModel: sound)
    } else {
        // Poslední sekunda intervalu nedostane .secondTick (engine pošle
        // .intervalTransition), takže tik při ztlumeném zvuku doplňujeme tady.
        playTickSound()
    }
}
```

---

## 8 · Migrace ze staré verze

Dvě věci najednou:

1. **Schéma SwiftData** – `isTicking: Bool = false` s default hodnotou je
   lightweight migrace, stačí přidat pole.
2. **Data** – hodnoty z UserDefaults se musí přelít do `TimerData(order: 0)`.
   **Směr je důležitý:** do 2.3 byl zdroj pravdy UserDefaults, kopie v `TimerData`
   jsou zastaralé (kapitola 2.4). Kopíruje se tedy UserDefaults → SwiftData,
   ne naopak.

```swift
//
//  SettingsMigration.swift
//  Jednorázový přesun nastavení z UserDefaults do aktivního TimerData.
//

import SwiftData
import Foundation

enum SettingsMigration {

    private static let flagKey = "didMigrateTimerSettingsToSwiftData"

    static func runIfNeeded(context: ModelContext, defaults: UserDefaults = .standard) {
        guard !defaults.bool(forKey: flagKey) else { return }

        let descriptor = FetchDescriptor<TimerData>(predicate: #Predicate { $0.order == 0 })
        guard let active = try? context.fetch(descriptor).first else {
            // Aktivní timer ještě neexistuje – migraci neoznačuj za hotovou,
            // spustí se při dalším startu, až ho ContentView založí.
            return
        }

        // Do 2.3 platily hodnoty z UserDefaults, kopie v TimerData byly zastaralé.
        if defaults.object(forKey: "rounds") != nil {
            active.rounds = defaults.integer(forKey: "rounds")
        }
        if defaults.object(forKey: "isVibrating") != nil {
            active.isVibrating = defaults.bool(forKey: "isVibrating")
        }
        active.isTicking = defaults.bool(forKey: "isTicking")

        // Zvuk se naopak řídil TimerData.selectedSound (SoundSettingsView psal
        // přímo do modelu), takže se nepřepisuje. Respektuje se jen tvrdé vypnutí.
        if defaults.object(forKey: "isSoundEnabled") != nil,
           defaults.bool(forKey: "isSoundEnabled") == false {
            active.selectedSound = nil
        }

        try? context.save()

        ["rounds", "isVibrating", "isTicking", "isSoundEnabled", "selectedSound",
         "selectedBackgroundIndex", "activeTimerId", "startedFromDeeplink"]
            .forEach(defaults.removeObject(forKey:))

        defaults.set(true, forKey: flagKey)
    }
}
```

Volat v `ContentView.onAppear` hned za `initializeDataIfNeeded()`.

**Uložené oblíbené** migraci nepotřebují: `rounds`, `selectedSound`
i `isVibrating` v nich sedí z okamžiku uložení. `isTicking` jim vyjde na `false`,
což přesně odpovídá tomu, jak se chovaly dosud (tikání součástí uloženého timeru
nebylo). `hasCountdown` zůstane `true` = dosavadní default.

---

## 9 · Deeplinky v2

`SharedTimerLink` je na rozšíření připravený – rezervovaný jmenný prostor `_`
(`SharedTimerLink.swift:83`) vznikl přesně kvůli tomuhle. Nic se nemusí bourat.

### 9.1 Nové parametry

| Klíč | Hodnota | Význam |
|---|---|---|
| `rounds` | `-1` nebo `1…31` | počet kol *(existuje)* |
| `_title` | text, max 64 znaků | název timeru *(existuje)* |
| `_sound` | `beep`, `gong`, … nebo `off` | zvuk přechodu, `off` = ticho |
| `_vibe` | `1` / `0` | vibrace |
| `_tick` | `1` / `0` | tikání každou sekundu |
| `_cd` | `1` / `0` | odpočet 3-2-1 |

Příklad generovaného odkazu:

```
https://gustavtraining.com/t?Work=20&Rest=10&rounds=8&_sound=bicycle&_vibe=1&_tick=0&_cd=1&_title=TABATA
```

Parser booleanů bere i `true/false`, `yes/no`, `on/off` (case-insensitive) –
odkazy se píšou i ručně. Generátor zapisuje vždy `1`/`0`.

### 9.2 Klíčové rozhodnutí: chybějící parametr = **zachovej současné**

Tohle je jediné pravidlo, na kterém celá zpětná kompatibilita stojí.

- Odkaz z verze 2.2/2.3 (kolují mezi lidmi, musí fungovat dál) `_sound` ani
  `_vibe` neobsahuje → nastavení příjemce se nesáhne → **chová se přesně jako
  dnes, žádná regrese.**
- Nové odkazy nesou všechno explicitně → přijdou tak, jak je odesílatel poslal.

Alternativa „chybějící = default" by u starých odkazů měnila chování a navíc by
nešlo poznat „nezmiňuje" od „schválně vypnuto". Proto ne.

Z toho plyne, že **generátor zapisuje všechna nastavení vždycky**, i když se
rovnají defaultu – jinak by příjemce zdědil svoje vlastní a poslaný trénink by
zněl jinak. Odkaz je delší, ale sdílený trénink je pak jednoznačný.

`rounds` zůstává výjimkou: chybí-li, je `-1` (nekonečno). Tak to funguje dnes
a generátor ho stejně píše vždycky, takže to potká jen ručně psané odkazy.

### 9.3 Změny v `SharedTimerLink`

```swift
extension SharedTimerLink {
    static let soundKey     = "_sound"
    static let vibrationKey = "_vibe"
    static let tickingKey   = "_tick"
    static let countdownKey = "_cd"

    /// Hodnota `_sound`, která znamená ticho. Žádný SoundModel.rawValue se s ní
    /// nesmí srazit.
    static let soundOffValue = "off"
}

/// Zvuk ze sdíleného odkazu. Samostatný typ, protože potřebujeme rozlišit
/// „odkaz zvuk neřeší" (nil) od „odkaz říká ticho" (.mute).
enum SharedSoundSelection: Equatable {
    case mute
    case sound(SoundModel)

    var model: SoundModel? {
        switch self {
        case .mute: return nil
        case .sound(let model): return model
        }
    }
}

struct SharedTimerLink: Equatable {
    let intervals: [IntervalData]
    let rounds: Int
    let title: String?

    // nil = odkaz parametr neobsahoval → zachovej současnou hodnotu
    let sound: SharedSoundSelection?
    let isVibrating: Bool?
    let isTicking: Bool?
    let hasCountdown: Bool?
}
```

Sloučení se současným nastavením – **jedna funkce, jasně testovatelná**:

```swift
extension SharedTimerLink {
    /// Složí výsledné nastavení: co odkaz nese, přebije; co nenese, zůstane.
    /// Intervaly a kola přebijí vždycky – bez nich by odkaz nedával smysl.
    func applied(to base: TimerSettings) -> TimerSettings {
        var result = base
        result.intervals = intervals
        result.rounds = rounds
        if let title { result.name = title }
        if let sound { result.sound = sound.model }
        if let isVibrating { result.isVibrating = isVibrating }
        if let isTicking { result.isTicking = isTicking }
        if let hasCountdown { result.hasCountdown = hasCountdown }
        return result
    }
}
```

### 9.4 Parser

Rozšíří se **jen** větev rezervovaného jmenného prostoru v `parse(items:…)`
(`SharedTimerLink.swift:194`). Zbytek pravidel zůstává beze změny.

```swift
// 2. + 3. Rezervovaný jmenný prostor
if key.hasPrefix(reservedPrefix) {
    switch lowerKey {
    case titleKey:
        if title == nil {
            let trimmed = (item.value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { title = String(trimmed.prefix(limits.maxTitleLength)) }
        }

    case soundKey:
        // Vyhrává první výskyt. Neznámý zvuk (odkaz z novější verze aplikace)
        // se ignoruje – nesmí skončit ztlumením.
        if sound == nil, let raw = item.value?.lowercased() {
            if raw == soundOffValue {
                sound = .mute
            } else if let model = SoundModel(rawValue: raw) {
                sound = .sound(model)
            }
        }

    case vibrationKey: if isVibrating   == nil { isVibrating   = parseBool(item.value) }
    case tickingKey:   if isTicking     == nil { isTicking     = parseBool(item.value) }
    case countdownKey: if hasCountdown  == nil { hasCountdown  = parseBool(item.value) }

    default:
        break  // neznámý rezervovaný klíč – ignoruj, interval z něj nikdy nevznikne
    }
    continue
}
```

```swift
/// Boolean ze sdíleného odkazu. `nil` = nesrozumitelná hodnota, parametr se ignoruje.
private static func parseBool(_ value: String?) -> Bool? {
    switch value?.lowercased() {
    case "1", "true", "yes", "on":   return true
    case "0", "false", "no", "off":  return false
    default:                         return nil
    }
}
```

Kolize s názvy intervalů řešit nemusíme – `escapedIntervalName`
(`SharedTimerLink.swift:255`) už dneska přidá mezeru každému názvu začínajícímu
`_`, takže interval pojmenovaný „_sound" projde jako „` _sound`" a nespadne do
rezervované větve. **Nový klíč tedy nemůže rozbít existující odkaz.**

### 9.5 Generátor

```swift
/// Sestaví sdílený odkaz z kompletního nastavení timeru.
///
/// Pořadí: intervaly → rounds → _sound → _vibe → _tick → _cd → _title.
/// Všechna nastavení se zapisují vždy, i když odpovídají defaultu – příjemce
/// nesmí zdědit vlastní hodnotu tam, kde odesílatel něco poslal.
static func url(settings: TimerSettings, limits: Limits = .default) -> URL? {
    var items: [URLQueryItem] = []

    for interval in settings.intervals.prefix(limits.maxIntervalCount) {
        guard let key = encode(escapedIntervalName(interval.name)), !key.isEmpty else { continue }
        items.append(URLQueryItem(name: key, value: String(interval.value)))
    }
    guard !items.isEmpty else { return nil }

    items.append(URLQueryItem(name: roundsKey,     value: String(settings.rounds)))
    items.append(URLQueryItem(name: soundKey,      value: settings.sound?.rawValue ?? soundOffValue))
    items.append(URLQueryItem(name: vibrationKey,  value: settings.isVibrating  ? "1" : "0"))
    items.append(URLQueryItem(name: tickingKey,    value: settings.isTicking    ? "1" : "0"))
    items.append(URLQueryItem(name: countdownKey,  value: settings.hasCountdown ? "1" : "0"))

    let trimmedTitle = settings.name.trimmingCharacters(in: .whitespacesAndNewlines)
    if !trimmedTitle.isEmpty,
       let encoded = encode(String(trimmedTitle.prefix(limits.maxTitleLength))) {
        items.append(URLQueryItem(name: titleKey, value: encoded))
    }

    var components = URLComponents()
    components.scheme = "https"
    components.host = shareHost
    components.path = webPath
    components.percentEncodedQueryItems = items
    return components.url
}
```

Volající ve `FavouritesView.deeplinkURL(for:)` se scvrkne na
`SharedTimerLink.url(settings: timer.settings, limits: limits)`.

### 9.6 Příjem odkazu

```swift
func handleSharedTimer(items: [URLQueryItem]) {
    let limits = SharedTimerLink.Limits(
        maxIntervalCount: AppConfig.maxTimerCount,
        maxIntervalValue: AppConfig.maxTimerValue,
        maxRounds: AppConfig.roundsOptions.last ?? 31
    )
    guard let link = SharedTimerLink.parse(items: items, limits: limits) else { return }

    // Odkaz přebíjí jen to, co skutečně nese – zbytek zůstane uživateli.
    let merged = link.applied(to: settings)

    apply(merged, resetState: true)   // engine
    persist(merged)                   // SwiftData, TimerData(order: 0)

    deeplinkLoadedTitle = link.title ?? ""
    deeplinkLoadToken += 1
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { self.showingSheet = true }
}
```

Oproti dnešku se navíc uloží `rounds` do modelu (chyba 2.4) a zvuk se projeví
hned, ne až po zavření Settings.

### 9.7 Co ještě zvážit

- **Nabídnout sdílení i u aktivního timeru.** Dneska je `ShareLink` jen
  u oblíbených a presetů (`FavouritesView`). Po sjednocení je „sdílej, co mám
  rozdělané" jednořádek a je to nejpřirozenější místo, kde uživatel sdílení hledá.
- **`_v=2` verzování** bych nedělal – jmenný prostor `_` plus pravidlo
  „chybí = zachovej" pokrývá rozšiřování i bez něj. Až přijde změna, která
  nejde udělat aditivně, přidej `_v` teprve tehdy.
- **Ikony v `FavouriteRowView`** ukazují smyčku, zvuk a vibrace
  (`FavouriteRowView.swift:53–61`). Tikání a odpočet tam po sjednocení chybí –
  buď doplnit ikony, nebo vědomě nechat (řádek už je docela plný).

---

## 10 · Postup implementace po fázích

Každá fáze je samostatně sestavitelná a otestovatelná.

**Fáze 1 – sjednocení úložiště** *(jádro, tady zmizí chyby 2.1–2.5)*
1. `Shared/TimerSettings.swift` – nový typ
2. `TimerData`: přidat `isTicking`, extension `settings` + `init(order:settings:)`
3. `SettingsMigration` + volání v `ContentView.onAppear`
4. `TimerViewModel`: `apply(_:resetState:)`, zahodit `@AppStorage` nastavení,
   odposlech `didChangeNotification` i `setSound`
5. `SettingsView`: přepnout přepínače na `currentTimerData` (pomocná
   `binding(_:)` přes keyPath); `selectTimer`/`saveTimer` na `settings`
6. `FavouritesView`, `SearchTabView`: totéž, ideálně sdílenou metodou
7. `AppSettings` → `AppPreferences`, smazat mrtvé klíče z `ContentView`

**Fáze 2 – deeplinky**
8. `SharedTimerLink`: nové klíče, `SharedSoundSelection`, optional pole, `parseBool`
9. `applied(to:)` + `url(settings:limits:)`
10. `handleSharedTimer` na `applied(to:)`; `FavouritesView.deeplinkURL` na nový generátor
11. testy (kapitola 11)

**Fáze 3 – úklid** *(volitelné, ale nabízí se)*
12. `AppConfig.defaultTimer` / `predefinedTimers` na `TimerSettings` (kapitola 12.1)
13. sdílení aktivního timeru
14. aktualizace `GustavTimer-Dokumentace.md` kapitol 4, 10 a 17

Rozsah odhaduju na ~350 upravených řádků, z toho většina je mazání.

---

## 11 · Testy

`SharedTimerLinkTests.swift` už pokrývá parsování dobře (364 řádků). Přidat:

```swift
@Test("Odkaz bez nových parametrů nesáhne na nastavení uživatele")
func legacyLinkPreservesSettings() throws {
    // Odkaz z verze 2.2.1, který lidem koluje v chatech.
    let link = try #require(parse("gustavtimerapp://timer?Work=40&Rest=20&rounds=4"))
    var base = TimerSettings.default
    base.sound = .gong; base.isVibrating = true; base.isTicking = true; base.hasCountdown = false

    let result = link.applied(to: base)

    #expect(result.sound == .gong)
    #expect(result.isVibrating == true)
    #expect(result.isTicking == true)
    #expect(result.hasCountdown == false)
    #expect(result.rounds == 4)              // co odkaz nese, přebije
}

@Test("_sound=off znamená ticho, ne „neřešeno“")
func explicitMuteOverrides() throws {
    let link = try #require(parse("https://gustavtraining.com/t?Work=40&_sound=off"))
    var base = TimerSettings.default
    base.sound = .gong
    #expect(link.applied(to: base).sound == nil)
}

@Test("Neznámý zvuk se ignoruje, nezpůsobí ztlumení")
func unknownSoundIsIgnored() throws {
    let link = try #require(parse("https://gustavtraining.com/t?Work=40&_sound=trumpet"))
    var base = TimerSettings.default
    base.sound = .gong
    #expect(link.applied(to: base).sound == .gong)
}

@Test("Boolean parametry berou i textové tvary", arguments: [
    ("_vibe=1", true), ("_vibe=true", true), ("_vibe=YES", true),
    ("_vibe=0", false), ("_vibe=false", false), ("_vibe=off", false)
])
func booleanForms(query: String, expected: Bool) throws {
    let link = try #require(parse("https://gustavtraining.com/t?Work=40&\(query)"))
    #expect(link.isVibrating == expected)
}

@Test("Generátor a parser jsou navzájem inverzní")
func roundTrip() throws {
    let original = TimerSettings(
        name: "THE COMEBACK",
        intervals: [IntervalData(value: 40, name: "Work"), IntervalData(value: 20, name: "Rest")],
        rounds: 4, sound: .whistle, isVibrating: true, isTicking: true, hasCountdown: false
    )
    let url = try #require(SharedTimerLink.url(settings: original))
    let link = try #require(parse(url.absoluteString))

    // Z prázdného základu musí vyjít přesně to, co šlo dovnitř.
    #expect(link.applied(to: .default) == original)
}

@Test("Interval pojmenovaný jako nový rezervovaný klíč odkaz nerozbije")
func intervalNamedLikeReservedKey() throws {
    let settings = TimerSettings(
        name: "X", intervals: [IntervalData(value: 30, name: "_sound")],
        rounds: 2, sound: .beep, isVibrating: false, isTicking: false, hasCountdown: true
    )
    let url = try #require(SharedTimerLink.url(settings: settings))
    let link = try #require(parse(url.absoluteString))
    #expect(link.intervals.count == 1)
    #expect(link.sound == .sound(.beep))   // interval nepřebil skutečný parametr
}
```

Co se testy nepokryje (SwiftData + UI) a je potřeba proklikat na simulátoru:

- uložit timer s tikáním + vypnutým odpočtem → vybrat jiný → vrátit se → sedí
- upgrade z předchozí verze: kola, vibrace a tikání se nesmí resetovat
- otevřít starý odkaz `gustavtimerapp://timer?Work=40&Rest=20&rounds=4` →
  moje nastavení zvuku zůstane
- otevřít nový odkaz s `_sound=off` → timer je opravdu potichu **hned**,
  ne až po zavření Settings

---

## 12 · Nálezy mimo zadání

Narazil jsem na ně při čtení, s ukládáním souvisí, ale nejsou součástí zadání.

### 12.1 `AppConfig.defaultTimer` je sdílená instance `@Model`

```swift
static let defaultTimer = TimerData(order: 0, name: "Gustav Timer", …)
```

Je to **jedna** instance `@Model` objektu, kterou tři místa vkládají do kontextu
(`ContentView.initializeDataIfNeeded`, `SettingsView.getOrCreateTimerData`,
`TimerViewModel.saveTimers`). Sdílet jednu instanci `@Model` napříč vloženími je
riskantní – kdo ji zmutuje, mutuje ji všem, a při `context.insert` se stejný
objekt může přiřadit dvakrát.

`AppConfig.predefinedTimers` má stejný problém z druhé strany: jsou to
`@Model` objekty, které do kontextu **nikdy nevstoupí** a přesto se předávají do
`FavouriteRowView`.

Oprava je po zavedení `TimerSettings` skoro zadarmo:

```swift
static let defaultTimer = TimerSettings.default                  // hodnota, ne @Model
static let predefinedTimers: [TimerSettings] = [ … ]             // taky hodnoty
```
a `TimerData` vzniká až v místě vkládání: `TimerData(order: 0, settings: AppConfig.defaultTimer)`.
`FavouriteRowView` pak bere `TimerSettings` a funguje pro uložené i presety stejně.

### 12.2 Mrtvý kód

- `ContentView.swift:28–31` – čtyři nepoužité `@AppStorage`
- `AppSettings.save(rounds:isVibrating:isSoundEnabled:)` – nikdo nevolá
- `Views/WhatsNew/WhatsNewView.swift` – placeholder, používá se `OnboardingView`
- `.github/copilot-instructions.md` popisuje strukturu, která už rok neexistuje
  (`GustavViewModel.swift`, `EditSheetView.swift`, „data persistence via
  UserDefaults", „max 5 timers", „no unit test target"). Agenti podle toho
  pracují – stojí za přepsání nebo smazání.

### 12.3 Dokumentace

Po implementaci aktualizovat `GustavTimer-Dokumentace.md`:
kapitolu 4 (tabulka polí `TimerData`), 10 (formát deeplinku) a 17 (klíče
UserDefaults – `startedFromDeeplink` tam je, ale v kódu neexistuje).

---

## Shrnutí jednou větou

Zavést `TimerSettings` jako jediný popis toho, co je timer, uložit ho celý do
SwiftData, nechat v UserDefaults jen nastavení zařízení – a deeplink pak rozšířit
tak, že chybějící parametr znamená „zachovej současné", takže staré odkazy dál
fungují beze změny a nové nesou trénink kompletní i se zvukem, vibracemi,
tikáním a odpočtem.
