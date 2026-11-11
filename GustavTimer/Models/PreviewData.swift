//
//  PreviewData.swift
//  GustavTimer
//
//  Created by Dalibor Janeček on 11.11.2026.
//
//  Ukázková data pro Xcode Preview. Kontejner žije jen v paměti, takže
//  Preview nesahá na skutečnou databázi a pokaždé začíná stejně.
//
//      #Preview {
//          SettingsView(context: PreviewData.container.mainContext)
//              .modelContainer(PreviewData.container)
//      }
//

import SwiftData

@MainActor
enum PreviewData {

    /// Aktivní timer a dva oblíbené. Aktivní timer je načtený z prvního
    /// oblíbeného a má neuloženou úpravu, ať je vidět stav „Upraveno“.
    static let container: ModelContainer = {
        let container = makeContainer()
        let context = container.mainContext

        let tabata = TimerData(order: 2, settings: PredefinedTimer.tabata.settings)
        let strength = TimerData(order: 1, settings: TimerSettings(
            name: "Síla 5×5",
            intervals: [
                IntervalData(value: 45, name: "Work"),
                IntervalData(value: 90, name: "Rest")
            ],
            rounds: 5,
            sound: .beep,
            isVibrating: true,
            ticking: .finalSeconds,
            hasCountdown: true
        ))
        context.insert(tabata)
        context.insert(strength)

        FavouriteTimers.load(tabata, in: context)
        TimerData.mainTimer(in: context).rounds = 6
        try? context.save()
        return container
    }()

    /// Jen výchozí aktivní timer, žádné oblíbené.
    static let emptyContainer: ModelContainer = {
        let container = makeContainer()
        TimerData.mainTimer(in: container.mainContext)
        try? container.mainContext.save()
        return container
    }()

    private static func makeContainer() -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        do {
            return try ModelContainer(for: TimerData.self, CustomImageModel.self, configurations: configuration)
        } catch {
            fatalError("Kontejner pro Preview se nepodařilo vytvořit: \(error)")
        }
    }
}
