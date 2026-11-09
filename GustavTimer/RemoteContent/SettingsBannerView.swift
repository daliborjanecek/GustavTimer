//
//  SettingsBannerView.swift
//  GustavTimer
//
//  Created by Dalibor Janeček on 09.11.2026.
//
//  Banner nahoře v nastavení. Platné stažené bannery mají přednost, jinak
//  se ukáže vestavěný banner (náhodná výzva z `AppConfig.bannerImages`).
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
            SettingsSection(label: AppConfig.bannerName) {
                banner.getImage()
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .overlay(alignment: .bottomLeading) {
                        Image(.youtubeLogo)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 18)
                            .padding()
                    }
                    .onTapGesture {
                        if let url = banner.getURL() {
                            Analytics.send(.externalLinkOpened, parameters: ["target": "banner", "banner_source": "builtin"])
                            UIApplication.shared.open(url)
                        }
                    }
            }
        }
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
        // Pevný poměr 16:9 jako u vestavěných bannerů. Obrázek s jiným
        // poměrem se vyplní a ořízne na středu.
        .aspectRatio(Self.aspectRatio, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
    }

    private static let aspectRatio: CGFloat = 16 / 9
}

private struct RemoteBannerCard: View {
    let item: RemoteBannerItem

    var body: some View {
        Color.clear
            .overlay {
                Image(uiImage: item.image)
                    .resizable()
                    .scaledToFill()
            }
            .clipped()
            .overlay(alignment: .bottomLeading) {
                icon.padding()
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: open)
    }

    @ViewBuilder
    private var icon: some View {
        switch item.banner.type {
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

    private func open() {
        var parameters = ["target": "banner", "banner_source": "remote", "banner_id": item.banner.id]
        if let type = item.banner.type {
            parameters["banner_type"] = type.rawValue
        }
        Analytics.send(.externalLinkOpened, parameters: parameters)
        AppLinkRouter.open(item.banner.url)
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
