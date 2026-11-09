//
//  RemoteContentDebugView.swift
//  GustavTimer
//
//  Created by Dalibor Janeček on 09.11.2026.
//
//  Vývojářské menu pro vzdálený obsah. Existuje jen v DEBUG sestavení –
//  v produkci se soubor nezkompiluje. Otevírá se pětinásobným klepnutím
//  na číslo verze na konci nastavení.
//
//  Texty jsou schválně `verbatim` – menu je jen pro vývojáře a nemá
//  plnit katalog lokalizací.
//

#if DEBUG
import SwiftUI

struct RemoteContentDebugView: View {
    @ObservedObject private var content = RemoteContentManager.shared
    @State private var showClearConfirmation = false

    var body: some View {
        List {
            Section {
                row("Poslední úspěch", format(content.lastSuccess))
                row("Poslední pokus", format(content.lastAttempt))
                row("Výsledek pokusu", attemptResult)
                if let error = content.lastError {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(verbatim: "Chyba")
                        Text(verbatim: error)
                            .font(.footnote.monospaced())
                            .foregroundStyle(.red)
                            .textSelection(.enabled)
                    }
                }
                row("Další automatická", nextSync)
                if content.isSyncing {
                    HStack {
                        Text(verbatim: "Probíhá synchronizace")
                        Spacer()
                        ProgressView()
                    }
                }
            } header: {
                Text(verbatim: "Synchronizace")
            }

            Section {
                row("schemaVersion", content.config.map { String($0.schemaVersion) } ?? "—")
                row("generatedAt", format(content.config?.generatedAt))
                row("Bannery", count(stored: content.config?.banners.count, shown: content.banners.count))
                row("Odkazy", count(stored: content.config?.links.count, shown: content.links.count))
                row("Pozadí", count(stored: content.config?.backgrounds.count, shown: content.backgrounds.count))
                row("Jazyk aplikace", content.currentLanguage)
            } header: {
                Text(verbatim: "Uložený obsah")
            } footer: {
                Text(verbatim: "Uloženo / zobrazeno teď (podle jazyka a platnosti).")
            }

            Section {
                Button {
                    Task { await content.sync() }
                } label: {
                    Text(verbatim: "Vynutit stažení API")
                }
                .disabled(content.isSyncing)

                Button {
                    content.resetSyncTime()
                } label: {
                    Text(verbatim: "Resetovat čas synchronizace")
                }

                Button(role: .destructive) {
                    showClearConfirmation = true
                } label: {
                    Text(verbatim: "Smazat stažená data")
                }
            } header: {
                Text(verbatim: "Akce")
            } footer: {
                Text(verbatim: content.endpoint.absoluteString)
                    .textSelection(.enabled)
            }
        }
        .navigationTitle(Text(verbatim: "Vzdálený obsah"))
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            Text(verbatim: "Smazat stažená data?"),
            isPresented: $showClearConfirmation,
            titleVisibility: .visible
        ) {
            Button(role: .destructive) {
                content.clearDownloadedData()
            } label: {
                Text(verbatim: "Smazat")
            }
        } message: {
            Text(verbatim: "Smaže konfiguraci z API a stažené obrázky. Aplikace se vrátí k vestavěnému obsahu, nové stažení se samo nespustí.")
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(verbatim: title)
            Spacer()
            Text(verbatim: value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }

    private var attemptResult: String {
        switch content.lastAttemptSucceeded {
        case .some(true):  return "úspěch"
        case .some(false): return "neúspěch"
        case nil:          return "—"
        }
    }

    private var nextSync: String {
        guard let next = content.nextAllowedSync else { return "při další příležitosti" }
        return next <= .now ? "při další příležitosti" : format(next)
    }

    private func count(stored: Int?, shown: Int) -> String {
        guard let stored else { return "— (vestavěné)" }
        return "\(stored) / \(shown)"
    }

    private func format(_ date: Date?) -> String {
        guard let date else { return "—" }
        let absolute = date.formatted(.dateTime.day().month().year().hour().minute().second())
        let relative = date.formatted(.relative(presentation: .numeric))
        return "\(absolute)\n\(relative)"
    }
}
#endif
