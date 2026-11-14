//
//  SettingsBannerView.swift
//  GustavTimer
//
//  Created by Dalibor Janeček on 09.11.2026.
//
//  Banner nahoře v nastavení. Platné stažené bannery mají přednost, jinak
//  se ukáže vestavěný banner (náhodná výzva z `AppConfig.bannerImages`).
//
//  Obrázek je přes celou šířku obrazovky až k hornímu okraji (pod lištou
//  s tlačítky) a spodkem se rozpouští do pozadí seznamu. Kreslí se ve dvou
//  částech, protože řádek `List` nejde roztáhnout ke krajům obrazovky:
//
//  - `SettingsBannerBackground` – obrázek za seznamem, posouvá se spolu
//    s obsahem a při přetažení dolů se natáhne,
//  - `SettingsBannerRow` – průhledný první řádek seznamu stejné výšky,
//    který drží místo, ikonu typu a reaguje na ťuknutí a swipe.
//
//      List {
//          SettingsBannerRow(banners: banners, selection: $selection, height: rowHeight)
//          …
//      }
//      .scrollContentBackground(.hidden)
//      .background(alignment: .top) {
//          SettingsBannerBackground(banners: banners, selection: selection, height: height, scrollOffset: offset)
//      }
//

import SwiftUI
import GustavUICore

// MARK: - Položka

/// Jeden banner v nastavení – stažený z API, nebo vestavěný.
enum SettingsBannerItem: Identifiable {
    case remote(RemoteBannerItem)
    case builtIn(BannerImageModel)

    var id: String {
        switch self {
        case .remote(let item): return "remote-\(item.id)"
        case .builtIn(let banner): return "builtin-\(banner.id)"
        }
    }

    var image: Image {
        switch self {
        case .remote(let item): return Image(uiImage: item.image)
        case .builtIn(let banner): return banner.getImage()
        }
    }

    /// Typ kvůli ikoně. Vestavěné bannery vedou na YouTube.
    var type: RemoteBannerType? {
        switch self {
        case .remote(let item): return item.banner.type
        case .builtIn: return .youtube
        }
    }

    @MainActor
    func open() {
        switch self {
        case .remote(let item):
            var parameters = ["target": "banner", "banner_source": "remote", "banner_id": item.banner.id]
            if let type = item.banner.type {
                parameters["banner_type"] = type.rawValue
            }
            Analytics.send(.externalLinkOpened, parameters: parameters)
            AppLinkRouter.open(item.banner.url)
        case .builtIn(let banner):
            guard let url = banner.getURL() else { return }
            Analytics.send(.externalLinkOpened, parameters: ["target": "banner", "banner_source": "builtin"])
            UIApplication.shared.open(url)
        }
    }

    /// Co ukázat: platné bannery z API, jinak jeden vestavěný.
    static func current(remote: [RemoteBannerItem], builtIn: BannerImageModel?) -> [SettingsBannerItem] {
        if !remote.isEmpty {
            return remote.map { .remote($0) }
        }
        return builtIn.map { [.builtIn($0)] } ?? []
    }
}

// MARK: - Rozměry

enum SettingsBannerLayout {
    /// Výška obrázku vůči šířce obrazovky (včetně části pod lištou).
    static let heightRatio: CGFloat = 3 / 4
    /// O kolik první sekce seznamu zajede do rozpuštěného spodku obrázku.
    static let overlap: CGFloat = 48
    /// Jak dlouho zůstane banner na očích, než přijde další.
    static let autoAdvanceInterval: Duration = .seconds(5)

    static func height(forWidth width: CGFloat) -> CGFloat {
        (width * heightRatio).rounded()
    }

    /// Výška průhledného řádku – obrázek bez části pod lištou a bez překryvu.
    static func rowHeight(forWidth width: CGFloat, topInset: CGFloat) -> CGFloat {
        max(height(forWidth: width) - topInset - overlap, 0)
    }
}

// MARK: - Obrázek za seznamem

struct SettingsBannerBackground: View {
    let banners: [SettingsBannerItem]
    let selection: Int
    /// Výška obrázku v klidu (`SettingsBannerLayout.height`).
    let height: CGFloat
    /// Posun seznamu: 0 v klidu, kladný při scrollu nahoru, záporný při přetažení dolů.
    let scrollOffset: CGFloat

    var body: some View {
        if let item = banners[safe: selection] ?? banners.first {
            let pull = max(-scrollOffset, 0)
            let scrolled = max(scrollOffset, 0)

            ZStack {
                item.image
                    .resizable()
                    .scaledToFill()
                    .id(item.id)
                    .transition(.opacity)
            }
            .frame(maxWidth: .infinity)
            .frame(height: height + pull)
            .clipped()
            .overlay {
                // Nahoře lehké ztmavení kvůli čitelnosti stavového řádku
                // a tlačítek, dole rozpuštění do pozadí seznamu.
                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0.35), location: 0),
                        .init(color: .black.opacity(0), location: 0.3),
                        .init(color: Color(.systemGroupedBackground).opacity(0), location: 0.55),
                        .init(color: Color(.systemGroupedBackground), location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .offset(y: -scrolled)
            .animation(.easeInOut(duration: 0.5), value: item.id)
            .ignoresSafeArea(edges: .top)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}

// MARK: - Průhledný řádek

struct SettingsBannerRow: View {
    let banners: [SettingsBannerItem]
    @Binding var selection: Int
    let height: CGFloat

    var body: some View {
        if let item = banners[safe: selection] ?? banners.first {
            Section {
                Color.clear
                    .frame(height: height)
                    .overlay(alignment: .bottomLeading) {
                        BannerTypeIcon(type: item.type)
                            .padding(.leading, 4)
                            .padding(.bottom, 8)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { item.open() }
                    .simultaneousGesture(swipe)
                    .accessibilityElement()
                    .accessibilityAddTraits(.isButton)
                    .accessibilityLabel(Text(AppConfig.bannerName))
                    .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            // Odpočet se restartuje i po ručním swipu, takže uživateli
            // banner neuteče hned po přetažení.
            .task(id: selection) {
                guard banners.count > 1 else { return }
                try? await Task.sleep(for: SettingsBannerLayout.autoAdvanceInterval)
                guard !Task.isCancelled else { return }
                withAnimation {
                    selection = (selection + 1) % banners.count
                }
            }
            .onChange(of: banners.map(\.id)) { _, _ in
                selection = 0
            }
        }
    }

    /// Vodorovný swipe přepne banner. Svislý pohyb nechá scrollovat seznam.
    private var swipe: some Gesture {
        DragGesture(minimumDistance: 20)
            .onEnded { value in
                let dx = value.translation.width
                guard banners.count > 1, abs(dx) > 50, abs(dx) > abs(value.translation.height) else { return }
                let step = dx < 0 ? 1 : -1
                withAnimation {
                    selection = (selection + step + banners.count) % banners.count
                }
            }
    }
}

// MARK: - Ikona

/// Ikona podle typu banneru. YouTube má vlastní logo z assetů.
private struct BannerTypeIcon: View {
    let type: RemoteBannerType?

    var body: some View {
        switch type {
        case .youtube:
            Image(.youtubeLogo)
                .resizable()
                .scaledToFit()
                .frame(height: 18)
        case .some(let type):
            Image(systemName: type.symbolName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.5), radius: 3)
        case nil:
            EmptyView()
        }
    }
}

private extension RemoteBannerType {
    /// SF Symbol ikony. YouTube má vlastní logo z assetů.
    var symbolName: String {
        switch self {
        case .timer:    return "timer"
        case .youtube:  return "play.rectangle.fill"
        case .app:      return "apps.iphone"
        case .web:      return "safari"
        case .appstore: return "arrow.down.app"
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
