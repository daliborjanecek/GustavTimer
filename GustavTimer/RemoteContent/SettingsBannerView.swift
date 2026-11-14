//
//  SettingsBannerView.swift
//  GustavTimer
//
//  Created by Dalibor Janeček on 09.11.2026.
//
//  Banner nahoře v nastavení. Platné stažené bannery mají přednost, jinak
//  se ukáže vestavěný banner (náhodná výzva z `AppConfig.bannerImages`).
//  Banner s nadpisem se kreslí jako velká karta (`HeroBannerCard`) – fotka
//  přecházející do tmavé plochy, nadpis, popis a tlačítko s přechodem.
//

import SwiftUI
import GustavUICore

struct SettingsBannerView: View {
    @ObservedObject private var remoteContent = RemoteContentManager.shared

    var body: some View {
        let banners = remoteContent.banners
        if banners.isEmpty {
            BuiltInBanner()
        } else {
            Section {
                RemoteBannerCarousel(items: banners)
            }
        }
    }
}

// MARK: - Vestavěný banner

private struct BuiltInBanner: View {
    /// Vybraný jednou za zobrazení nastavení, ať se obrázek při překreslení nemění.
    @State private var banner = AppConfig.bannerImages.randomElement()

    var body: some View {
        if let banner {
            Section {
                HeroBannerCard(
                    image: banner.getImage(),
                    title: Text(banner.title),
                    subtitle: Text(banner.subtitle),
                    buttonLabel: Text(banner.buttonLabel),
                    icon: .youtube,
                    action: { open(banner) }
                )
                .aspectRatio(HeroBannerCard.aspectRatio, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: HeroBannerCard.cornerRadius))
                .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
            }
        }
    }

    private func open(_ banner: BannerImageModel) {
        guard let url = banner.getURL() else { return }
        Analytics.send(.externalLinkOpened, parameters: ["target": "banner", "banner_source": "builtin"])
        UIApplication.shared.open(url)
    }
}

// MARK: - Stažené bannery

/// Jeden banner, nebo víc bannerů v `TabView`, které se samy přepínají
/// a po posledním začnou znovu prvním.
private struct RemoteBannerCarousel: View {
    let items: [RemoteBannerItem]

    @State private var selection = 0

    /// Jak dlouho zůstane banner na očích, než přijde další.
    private static let autoAdvanceInterval: Duration = .seconds(5)

    /// Má aspoň jeden banner text, kreslí se celý carousel jako velké karty
    /// (všechny stránky `TabView` musí mít stejnou výšku).
    private var usesHeroLayout: Bool {
        items.contains { $0.banner.title != nil }
    }

    var body: some View {
        Group {
            if items.count == 1, let item = items.first {
                RemoteBannerCard(item: item)
            } else {
                TabView(selection: $selection) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        RemoteBannerCard(item: item)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                // Odpočet se restartuje i po ručním swipu, takže uživateli
                // banner neuteče hned po přetažení.
                .task(id: selection) {
                    try? await Task.sleep(for: Self.autoAdvanceInterval)
                    guard !Task.isCancelled, items.count > 1 else { return }
                    withAnimation {
                        selection = (selection + 1) % items.count
                    }
                }
                .onChange(of: items.map(\.id)) { _, _ in
                    selection = 0
                }
            }
        }
        // Pevný poměr: 16:9 u čistě obrázkových bannerů, vyšší u karet
        // s textem. Obrázek s jiným poměrem se vyplní a ořízne na středu.
        .aspectRatio(usesHeroLayout ? HeroBannerCard.aspectRatio : 16 / 9, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: HeroBannerCard.cornerRadius))
        .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
    }
}

private struct RemoteBannerCard: View {
    let item: RemoteBannerItem

    var body: some View {
        if let title = item.banner.title {
            HeroBannerCard(
                image: Image(uiImage: item.image),
                title: Text(verbatim: title),
                subtitle: item.banner.subtitle.map { Text(verbatim: $0) },
                buttonLabel: item.banner.buttonLabel.map { Text(verbatim: $0) },
                icon: item.banner.type,
                action: open
            )
        } else {
            imageOnly
        }
    }

    /// Banner bez textu – jen obrázek s ikonou typu v rohu.
    private var imageOnly: some View {
        Color.clear
            .overlay {
                Image(uiImage: item.image)
                    .resizable()
                    .scaledToFill()
            }
            .clipped()
            .overlay(alignment: .bottomLeading) {
                BannerTypeIcon(type: item.banner.type)
                    .padding()
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: open)
    }

    private func open() {
        var parameters = ["target": "banner", "banner_source": "remote", "banner_id": item.banner.id]
        if let type = item.banner.type {
            parameters["banner_type"] = type.rawValue
        }
        Analytics.send(.externalLinkOpened, parameters: parameters)
        AppLinkRouter.open(item.banner.url)
    }
}

// MARK: - Velká karta

/// Karta ve stylu „paywallu“: fotka nahoře plynule přechází do tmavé
/// plochy, pod ní velký nadpis, popis a pilulkové tlačítko s přechodem.
/// Ťuknout jde kamkoli na kartu, nejen na tlačítko.
///
///     HeroBannerCard(image: Image(.gustavChallenge),
///                    title: Text("BANNER_CHALLENGE_TITLE"),
///                    subtitle: Text("BANNER_CHALLENGE_SUBTITLE"),
///                    buttonLabel: Text("BANNER_CHALLENGE_BUTTON"),
///                    icon: .youtube) { … }
private struct HeroBannerCard: View {
    let image: Image
    let title: Text
    var subtitle: Text?
    var buttonLabel: Text?
    var icon: RemoteBannerType?
    let action: () -> Void

    /// Šířka : výška celé karty. Fotka 16:9 zabírá horní dvě třetiny.
    static let aspectRatio: CGFloat = 1 / 0.9
    static let cornerRadius: CGFloat = 24

    /// Tmavá plocha pod fotkou – stejná ve světlém i tmavém režimu,
    /// aby bílý text měl vždy kontrast.
    private static let background = Color(red: 0.10, green: 0.10, blue: 0.11)

    /// Přechod tlačítka z fialové do modré.
    private static var buttonGradient: LinearGradient {
        LinearGradient(
            colors: [Color(red: 0.62, green: 0.25, blue: 0.80), Color(red: 0.27, green: 0.42, blue: 0.97)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    var body: some View {
        GeometryReader { proxy in
            let imageHeight = proxy.size.width * 9 / 16

            ZStack(alignment: .top) {
                Self.background

                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: imageHeight)
                    .clipped()
                    // Spodní třetina fotky se rozpustí do pozadí karty.
                    .overlay {
                        LinearGradient(
                            stops: [
                                .init(color: Self.background.opacity(0), location: 0.45),
                                .init(color: Self.background.opacity(0.75), location: 0.8),
                                .init(color: Self.background, location: 1)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }

                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: action)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    private var content: some View {
        VStack(spacing: 8) {
            title
                .font(.system(.title2, design: .default, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.7)

            if let subtitle {
                subtitle
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(3)
                    .minimumScaleFactor(0.8)
            }

            if let buttonLabel {
                button(label: buttonLabel)
                    .padding(.top, 8)
            }
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }

    private func button(label: Text) -> some View {
        HStack(spacing: 8) {
            if icon != nil {
                BannerTypeIcon(type: icon, tint: .white)
            }
            label
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .frame(height: 50)
        .background(Self.buttonGradient, in: Capsule())
    }
}

/// Ikona podle typu banneru. YouTube má vlastní logo z assetů.
private struct BannerTypeIcon: View {
    let type: RemoteBannerType?
    /// `nil` = výchozí bílá se stínem pro ikonu přes fotku.
    var tint: Color? = nil

    var body: some View {
        switch type {
        case .youtube where tint == nil:
            Image(.youtubeLogo)
                .resizable()
                .scaledToFit()
                .frame(height: 18)
        case .some(let type):
            Image(systemName: type.symbolName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(tint ?? .white)
                .shadow(color: .black.opacity(tint == nil ? 0.5 : 0), radius: 3)
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

#Preview {
    List {
        SettingsBannerView()
    }
}

#Preview("Velká karta") {
    List {
        Section {
            HeroBannerCard(
                image: Image(.gustavChallenge),
                title: Text("BANNER_CHALLENGE_TITLE"),
                subtitle: Text("BANNER_CHALLENGE_SUBTITLE"),
                buttonLabel: Text("BANNER_CHALLENGE_BUTTON"),
                icon: .youtube,
                action: {}
            )
            .aspectRatio(HeroBannerCard.aspectRatio, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: HeroBannerCard.cornerRadius))
            .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
        }
    }
}
