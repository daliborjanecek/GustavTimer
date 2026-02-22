//
//  TimerEngine.swift
//  GustavTimer
//
//  Sdílená logika časovače pro iPhone i Apple Watch.
//  Neobsahuje žádné platform-specific importy (UIKit, WatchKit).
//  Závisí pouze na Foundation a Combine.
//
//  TimerEngine je "mozek" aplikace – řídí odpočítávání, přepínání intervalů
//  a kol. Neví nic o UI, zvucích ani vibracích. Místo toho oznamuje události
//  přes callbacky (onFeedback, onStart, onStop), které si každá platforma
//  napojí po svém.
//
//  ┌─────────────────────────────────────────────────────────────┐
//  │                       TimerEngine                           │
//  │                                                             │
//  │   intervals: [Work 20s, Rest 10s]    rounds: 8             │
//  │                                                             │
//  │   start() → tick 10ms → remainingTime -= 10ms              │
//  │                  │                                          │
//  │                  └─ remainingTime <= 0?                     │
//  │                       ├─ další interval → onFeedback(.intervalTransition)
//  │                       └─ konec kola     → onFeedback(.roundComplete)
//  │                            └─ poslední kolo → onFeedback(.timerEnd)
//  │                                                             │
//  └─────────────────────────────────────────────────────────────┘
//          │                          │
//    ┌─────▼──────┐           ┌──────▼───────┐
//    │ iOS VM     │           │ Watch VM     │
//    │ UIKit      │           │ WKInterface  │
//    │ haptics    │           │ haptics      │
//    │ AVAudio    │           │ system sound │
//    │ idle timer │           │ RT session   │
//    └────────────┘           └──────────────┘
//
//  Základní použití:
//
//      let engine = TimerEngine()
//
//      // Nahrát intervaly (např. Tabata)
//      engine.loadIntervals([
//          IntervalData(value: 20, name: "Work"),
//          IntervalData(value: 10, name: "Rest")
//      ])
//      engine.rounds = 8
//
//      // Napojit platformovou zpětnou vazbu
//      engine.onFeedback = { feedback in
//          switch feedback {
//          case .intervalTransition: print("Další interval!")
//          case .roundComplete:      print("Kolo hotovo!")
//          case .timerEnd:           print("Konec!")
//          }
//      }
//
//      // Spustit
//      engine.start()
//
//  SwiftUI binding (TimerEngine je ObservableObject):
//
//      // V ViewModel – přeposílání objectWillChange do vlastního publisheru:
//      engine.objectWillChange
//          .sink { [weak self] _ in self?.objectWillChange.send() }
//          .store(in: &cancellables)
//
//      // Nebo přímo ve View (jednoduchý případ):
//      @StateObject var engine = TimerEngine()
//      Text("\(engine.count)")  // automaticky se aktualizuje
//

import Foundation
import Combine
import SwiftUI // TODO: vymazat

// MARK: - TimerFeedback

/// Typ zpětné vazby, kterou engine požaduje od platformy.
/// Engine sám žádný zvuk ani vibraci nevytváří – pouze říká "teď by se mělo zavibrovat".
///
/// Příklad napojení na iOS:
///
///     engine.onFeedback = { feedback in
///         switch feedback {
///         case .intervalTransition:
///             UIImpactFeedbackGenerator(style: .light).impactOccurred()
///         case .roundComplete:
///             UINotificationFeedbackGenerator().notificationOccurred(.success)
///         case .timerEnd:
///             UINotificationFeedbackGenerator().notificationOccurred(.error)
///         }
///     }
///
/// Příklad napojení na watchOS:
///
///     engine.onFeedback = { feedback in
///         switch feedback {
///         case .intervalTransition:
///             WKInterfaceDevice.current().play(.click)
///         case .roundComplete:
///             WKInterfaceDevice.current().play(.success)
///         case .timerEnd:
///             WKInterfaceDevice.current().play(.failure)
///         }
///     }
enum TimerFeedback {
    /// Přechod na další interval v rámci kola (např. Work → Rest).
    /// Typicky lehká vibrace.
    case intervalTransition

    /// Dokončení celého kola (prošly všechny intervaly, začíná další kolo).
    /// Typicky výraznější vibrace + zvuk.
    case roundComplete

    /// Konec celého timeru (poslední kolo dokončeno).
    /// Typicky silná vibrace + zvuk, engine se automaticky resetuje.
    case timerEnd
}

// MARK: - TimerEngine

/// Jádro odpočítávání – čistá logika bez UI a platform-specific API.
///
/// Životní cyklus:
///     1. Vytvoření:     let engine = TimerEngine()
///     2. Konfigurace:   engine.loadIntervals([...]), engine.rounds = 8
///     3. Callbacky:     engine.onFeedback = { ... }
///     4. Spuštění:      engine.start()
///     5. Běh:           engine tikne každých 10ms, aktualizuje remainingTime
///     6. Přechody:      automaticky přepíná intervaly a kola
///     7. Zastavení:     engine.stop() nebo automaticky po posledním kole
///     8. Reset:         engine.reset() – vrátí vše na začátek
class TimerEngine: ObservableObject {

    // MARK: - Konfigurace

    /// Maximální počet intervalů v jednom kole.
    /// Při dosažení limitu addInterval() nic nepřidá.
    ///
    ///     let engine = TimerEngine(maxTimers: 10)
    ///     engine.isTimerFull  // true pokud intervals.count >= 10
    let maxTimers: Int

    /// Maximální délka jednoho intervalu v sekundách.
    /// Samotný engine tuto hodnotu nevynucuje – slouží jako referenční konstanta
    /// pro UI (slider/stepper limit).
    let maxCountdownValue: Int

    /// Kontrola, zda je dosaženo maximálního počtu intervalů.
    ///
    ///     if !engine.isTimerFull {
    ///         engine.addInterval(IntervalData(value: 30, name: "Work"))
    ///     }
    var isTimerFull: Bool { intervals.count >= maxTimers }

    // MARK: - Publikovaný stav (@Published)
    //
    // Všechny tyto properties jsou private(set) – měnit je může pouze engine.
    // SwiftUI view se na ně napojí přes ObservableObject / objectWillChange.

    /// Zda timer aktuálně běží (odpočítává).
    ///
    ///     Text(engine.isRunning ? "STOP" : "START")
    @Published private(set) var isRunning = false

    /// Index aktuálně běžícího intervalu v poli `intervals`.
    ///
    ///     let currentName = engine.intervals[engine.activeTimerIndex].name
    ///
    /// Používá se i v ProgressArrayView pro zvýraznění aktivního segmentu:
    ///
    ///     ForEach(Array(engine.intervals.enumerated()), id: \.offset) { index, interval in
    ///         ProgressBar(
    ///             progress: index == engine.activeTimerIndex
    ///                 ? engine.progress
    ///                 : (index < engine.activeTimerIndex ? 1.0 : 0.0)
    ///         )
    ///     }
    @Published private(set) var activeTimerIndex: Int = 0

    /// Počet dokončených kol (1-based).
    /// Hodnota 0 znamená, že timer ještě nebyl spuštěn.
    /// Po start() se nastaví na 1 (= první kolo).
    ///
    ///     Text("\(engine.finishedRounds)/\(engine.rounds)")  // "3/8"
    @Published private(set) var finishedRounds: Int = 0

    /// Zbývající čas v aktuálním intervalu (sub-sekundová přesnost).
    /// Aktualizuje se každých 10ms během běhu.
    ///
    ///     // Pro zobrazení použij raději formattedCurrentTime():
    ///     Text(engine.formattedCurrentTime(format: .seconds))  // "45"
    @Published private(set) var remainingTime: Duration = .seconds(0)

    /// Pole intervalů tvořící jedno kolo.
    /// Toto je read-write – intervaly lze měnit i za běhu (ale raději po reset()).
    ///
    ///     engine.intervals = [
    ///         IntervalData(value: 20, name: "Work"),
    ///         IntervalData(value: 10, name: "Rest")
    ///     ]
    @Published var intervals: [IntervalData] = []

    // MARK: - Nastavení

    /// Počet kol. -1 = nekonečno (timer se opakuje dokud ho nezastavíš).
    ///
    ///     engine.rounds = 8    // Tabata: 8 kol
    ///     engine.rounds = -1   // nekonečné opakování
    var rounds: Int = -1

    // MARK: - Callbacky pro platformu
    //
    // Engine sám neprovádí žádné side-effecty (zvuky, vibrace, idle timer).
    // Místo toho volá callbacky, které si platforma nastaví při inicializaci.

    /// Volá se při potřebě haptické/zvukové zpětné vazby.
    /// Viz TimerFeedback enum výše pro příklady napojení.
    var onFeedback: ((TimerFeedback) -> Void)?

    /// Volá se při spuštění timeru.
    /// iOS typicky zakáže idle timer:
    ///
    ///     engine.onStart = {
    ///         UIApplication.shared.isIdleTimerDisabled = true
    ///     }
    ///
    /// watchOS typicky spustí Extended Runtime Session:
    ///
    ///     engine.onStart = { [weak self] in
    ///         self?.extendedSession.start()
    ///     }
    var onStart: (() -> Void)?

    /// Volá se při zastavení timeru (manuálním i automatickém po posledním kole).
    ///
    ///     engine.onStop = {
    ///         UIApplication.shared.isIdleTimerDisabled = false
    ///     }
    var onStop: (() -> Void)?

    // MARK: - Privátní

    /// Reference na asynchronní Task, který provádí tikání.
    /// Cancel se provede při stop() nebo novém start().
    private var timerTask: Task<Void, Never>?

    // MARK: - Vypočítané vlastnosti

    /// Zbývající čas v celých sekundách, omezený délkou aktuálního intervalu.
    /// Nikdy nepřekročí délku intervalu (chrání proti přetečení po pauze).
    ///
    ///     Text("\(engine.count)")  // "45"
    ///
    /// Pro formátovaný výstup použij raději:
    ///     engine.formattedCurrentTime(format: .seconds)
    var count: Int {
        guard activeTimerIndex < intervals.count else { return 0 }
        return min(
            Int(remainingTime.components.seconds),
            Int(intervals[activeTimerIndex].duration.components.seconds)
        )
    }

    /// Pokrok aktivního intervalu jako hodnota 0.0 – 1.0.
    /// 0.0 = interval právě začal, 1.0 = interval skončil.
    /// Počítá se z milisekund pro plynulou animaci progress baru.
    ///
    ///     ProgressView(value: engine.progress)
    ///
    ///     // Nebo pro vlastní progress bar:
    ///     Rectangle()
    ///         .frame(width: totalWidth * engine.progress)
    var progress: Double {
        guard activeTimerIndex < intervals.count else { return 0.0 }
        let totalDuration = intervals[activeTimerIndex].duration
        guard totalDuration > .zero else { return 0.0 }

        let totalMs = Double(totalDuration.components.seconds) * 1000 +
                      Double(totalDuration.components.attoseconds) / 1e15
        let remainingMs = Double(remainingTime.components.seconds) * 1000 +
                          Double(remainingTime.components.attoseconds) / 1e15

        guard totalMs > 0 else { return 0.0 }

        let elapsedMs = totalMs - remainingMs
        return max(0.0, min(1.0, elapsedMs / totalMs))
    }

    // MARK: - Inicializace

    /// Vytvoří nový TimerEngine s volitelnými limity.
    ///
    ///     // Výchozí hodnoty (10 intervalů, max 600s)
    ///     let engine = TimerEngine()
    ///
    ///     // Vlastní limity
    ///     let engine = TimerEngine(maxTimers: 5, maxCountdownValue: 300)
    ///
    ///     // S AppConfig hodnotami (v iOS ViewModel)
    ///     let engine = TimerEngine(
    ///         maxTimers: AppConfig.maxTimerCount,
    ///         maxCountdownValue: AppConfig.maxTimerValue
    ///     )
    ///
    /// Po vytvoření engine obsahuje výchozí intervaly [Work 60s, Rest 30s].
    init(maxTimers: Int = 10,
         maxCountdownValue: Int = 600) {
        self.maxTimers = maxTimers
        self.maxCountdownValue = maxCountdownValue
        setupDefaultIntervals()
    }

    /// Nastaví výchozí intervaly [Work 60s, Rest 30s].
    /// Volá se automaticky při init() – není třeba volat ručně.
    private func setupDefaultIntervals() {
        intervals = [
            IntervalData(value: 60, name: "Work"),
            IntervalData(value: 30, name: "Rest")
        ]
        remainingTime = intervals[0].duration
    }

    // MARK: - Ovládání timeru

    /// Toggle: pokud timer běží, zastaví ho; pokud stojí, spustí ho.
    ///
    ///     Button(engine.isRunning ? "STOP" : "START") {
    ///         engine.startStop()
    ///     }
    func startStop() {
        isRunning ? stop() : start()
    }

    /// Spustí odpočet. Pokud timer stojí na nule, nastaví remainingTime
    /// na délku aktuálního intervalu.
    ///
    /// Interně vytvoří async Task, který každých 10ms volá tick().
    /// ContinuousClock zajišťuje přesné časování i při zatížení CPU.
    ///
    ///     engine.start()
    ///     // engine.isRunning == true
    ///     // engine.finishedRounds == 1 (první kolo)
    func start() {
        if finishedRounds == 0 { finishedRounds = 1 }

        if remainingTime <= .zero {
            remainingTime = intervals[activeTimerIndex].duration
        }

        isRunning = true
        onStart?()

        timerTask?.cancel()
        timerTask = Task { [weak self] in
            guard let self else { return }

            let tickInterval: Duration = .milliseconds(10)
            let clock = ContinuousClock()

            while !Task.isCancelled && self.isRunning {
                let start = clock.now

                await MainActor.run {
                    self.tick(tickInterval)
                }

                let elapsed = clock.now - start
                let sleepTime = tickInterval - elapsed
                if sleepTime > .zero {
                    try? await Task.sleep(for: sleepTime)
                }
            }
        }
    }

    /// Zastaví timer bez resetování pozice.
    /// Po opětovném start() pokračuje od místa, kde skončil.
    ///
    ///     engine.stop()
    ///     // engine.isRunning == false
    ///     // engine.remainingTime zůstává na poslední hodnotě
    ///     // engine.activeTimerIndex zůstává
    func stop() {
        isRunning = false
        timerTask?.cancel()
        timerTask = nil
        onStop?()
    }

    /// Zastaví timer a vrátí vše na začátek (první interval, první kolo).
    ///
    ///     engine.reset()
    ///     // engine.isRunning == false
    ///     // engine.activeTimerIndex == 0
    ///     // engine.finishedRounds == 0
    ///     // engine.remainingTime == intervals[0].duration
    func reset() {
        stop()
        finishedRounds = 0
        activeTimerIndex = 0
        if !intervals.isEmpty {
            remainingTime = intervals[0].duration
        }
    }

    /// Přeskočí aktuální interval – nastaví remainingTime na nulu,
    /// což při dalším tiku vyvolá switchToNextInterval().
    ///
    ///     // Uživatel tapne "Skip" tlačítko
    ///     engine.skipCurrentInterval()
    func skipCurrentInterval() {
        remainingTime = .zero
    }

    // MARK: - Správa intervalů

    /// Přidá interval na konec pole. Pokud je dosaženo maxTimers, nepřidá nic.
    ///
    ///     // S výchozím intervalem (5s)
    ///     engine.addInterval()
    ///
    ///     // S konkrétním intervalem
    ///     engine.addInterval(IntervalData(value: 30, name: "Sprint"))
    func addInterval(_ interval: IntervalData? = nil) {
        guard !isTimerFull else { return }
        let newInterval = interval ?? IntervalData(
            value: 5,
            name: "Kolo \(intervals.count + 1)"
        )
        intervals.append(newInterval)
    }

    /// Odebere intervaly na zadaných pozicích (pro SwiftUI onDelete modifier).
    ///
    ///     List {
    ///         ForEach(engine.intervals) { interval in ... }
    ///             .onDelete { offsets in
    ///                 engine.removeInterval(at: offsets)
    ///             }
    ///     }
    func removeInterval(at offsets: IndexSet) {
        intervals.remove(atOffsets: offsets)
    }

    /// Odebere interval na konkrétním indexu.
    ///
    ///     engine.removeInterval(at: 2)  // odebere třetí interval
    func removeInterval(at index: Int) {
        guard index < intervals.count else { return }
        intervals.remove(at: index)
    }

    /// Nahraje nové intervaly a volitelně resetuje stav.
    /// Hlavní způsob jak dostat data z persistence (SwiftData, WatchConnectivity).
    ///
    ///     // Načtení z databáze
    ///     let intervals = timerData.intervals
    ///     engine.loadIntervals(intervals, resetState: true)
    ///
    ///     // Načtení bez resetu (např. hot-reload z Watch)
    ///     engine.loadIntervals(intervals, resetState: false)
    func loadIntervals(_ newIntervals: [IntervalData], resetState: Bool = true) {
        intervals = newIntervals
        if resetState {
            reset()
        }
    }

    // MARK: - Formátování času

    /// Formátuje libovolnou Duration na čitelný řetězec.
    /// Pod minutu zobrazí jen sekundy, nad minutu minuty:sekundy.
    ///
    ///     engine.formattedTime(from: .seconds(45))   // "45"
    ///     engine.formattedTime(from: .seconds(90))   // "1:30"
    ///     engine.formattedTime(from: .seconds(3600)) // "60:00"
    ///
    /// Používá se typicky pro zobrazení celkové délky intervalu v nastavení:
    ///
    ///     Text(engine.formattedTime(from: interval.duration))
    func formattedTime(from duration: Duration) -> String {
        let totalSeconds = Int(duration.components.seconds)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60

        return minutes > 0
            ? String(format: "%d:%02d", minutes, seconds)
            : String(format: "%d", seconds)
    }

    /// Formátuje aktuální zbývající čas podle zvoleného formátu.
    ///
    ///     // Celé sekundy (portrait, Watch)
    ///     engine.formattedCurrentTime(format: .seconds)
    ///     // → "45"
    ///
    ///     // Minuty:sekundy.setiny (landscape, přesné měření)
    ///     engine.formattedCurrentTime(format: .minutesSecondsHundredths)
    ///     // → "0:45.32"  nebo  "2:00.05"
    func formattedCurrentTime(format: TimeDisplayFormat) -> String {
        switch format {
        case .seconds:
            return "\(count)"
        case .minutesSecondsHundredths:
            let components = remainingTime.components
            let minutes = Int(components.seconds) / 60
            let seconds = Int(components.seconds) % 60
            let tenths = Int(components.attoseconds / 10_000_000_000_000_000)

            if minutes > 0 {
                return String(format: "%d:%02d.%02d", minutes, seconds, tenths)
            } else {
                return String(format: "%d.%02d", seconds, tenths)
            }
        }
    }

    // MARK: - Výpočet poměrů pro progress bary

    /// Poměr délky intervalu vůči celkové délce jednoho kola (0.0 – 1.0).
    /// Používá se pro výpočet šířky segmentů v progress baru.
    ///
    ///     // Kolo: [Work 20s, Rest 10s] → celkem 30s
    ///     engine.timeRatio(for: 0)  // 0.667 (20/30) – Work zabírá 2/3
    ///     engine.timeRatio(for: 1)  // 0.333 (10/30) – Rest zabírá 1/3
    ///
    /// Příklad výpočtu šířky progress baru:
    ///
    ///     let totalWidth = geometry.size.width - spacing
    ///     let barWidth = totalWidth * engine.timeRatio(for: index)
    func timeRatio(for index: Int) -> Double {
        let totalDuration = intervals.reduce(0.0) {
            $0 + Double(truncating: $1.duration.components.seconds as NSNumber)
        }
        guard totalDuration > 0, index < intervals.count else { return 0 }

        let intervalDuration = Double(
            truncating: intervals[index].duration.components.seconds as NSNumber
        )
        return intervalDuration / totalDuration
    }

    // MARK: - Privátní logika

    /// Jeden tik časovače – odečte uplynulý čas a zkontroluje přechod.
    /// Volá se na MainActor (kvůli @Published property updates).
    private func tick(_ interval: Duration) {
        remainingTime -= interval

        if remainingTime <= .zero {
            switchToNextInterval()
        }
    }

    /// Přechod na další interval v kole.
    ///
    /// Pokud existuje další interval → nastaví remainingTime a zavolá onFeedback(.intervalTransition).
    /// Pokud je to poslední interval → zavolá handleRoundCompletion().
    /// Nulové intervaly (duration <= 0) se automaticky přeskakují.
    private func switchToNextInterval() {
        activeTimerIndex += 1

        if activeTimerIndex >= intervals.count {
            handleRoundCompletion()
        } else {
            onFeedback?(.intervalTransition)
            remainingTime = intervals[activeTimerIndex].duration

            // Přeskočit nulové intervaly
            if intervals[activeTimerIndex].duration <= .zero {
                switchToNextInterval()
            }
        }
    }

    /// Zpracování konce kola.
    ///
    /// Tři scénáře:
    ///     1. rounds == -1 (nekonečno) → nové kolo, onFeedback(.roundComplete)
    ///     2. finishedRounds < rounds  → nové kolo, onFeedback(.roundComplete)
    ///     3. finishedRounds == rounds → konec, onFeedback(.timerEnd), reset()
    private func handleRoundCompletion() {
        activeTimerIndex = 0

        if rounds == -1 || finishedRounds < rounds {
            onFeedback?(.roundComplete)
            finishedRounds += 1
            remainingTime = intervals[0].duration
        } else {
            onFeedback?(.timerEnd)
            reset()
        }
    }
}
