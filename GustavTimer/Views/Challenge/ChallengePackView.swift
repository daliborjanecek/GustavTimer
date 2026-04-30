//
//  ChallengePackView.swift
//  GustavTimer
//
//  Surface for the Challenge video pack: download / progress / play states
//  on iOS 26+, YouTube fallback elsewhere.
//

import SwiftUI

struct ChallengePackBannerView: View {
    let bannerImage: BannerImageModel

    var body: some View {
        Group {
            if #available(iOS 26.0, *) {
                ChallengePackView(bannerImage: bannerImage)
            } else {
                ChallengePackYouTubeFallback(bannerImage: bannerImage)
            }
        }
    }
}

@available(iOS 26.0, *)
struct ChallengePackView: View {
    let bannerImage: BannerImageModel

    @StateObject private var manager = ChallengePackManager()
    @State private var showVideoList = false

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            bannerImage.getImage()
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 16))

            controlOverlay
                .padding()
        }
        .onTapGesture { handleTap() }
        .sheet(isPresented: $showVideoList) {
            ChallengeVideoListView(videoURLs: manager.videoURLs())
        }
    }

    @ViewBuilder
    private var controlOverlay: some View {
        switch manager.state {
        case .notDownloaded:
            HStack(spacing: 6) {
                Image(systemName: "arrow.down.circle.fill")
                Text("CHALLENGE_DOWNLOAD")
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())

        case .downloading(let progress):
            HStack(spacing: 8) {
                ProgressView(value: progress)
                    .frame(width: 100)
                Text("\(Int(progress * 100))%")
                    .font(.caption.monospacedDigit())
                Button {
                    manager.cancelDownload()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())

        case .downloaded:
            HStack(spacing: 6) {
                Image(systemName: "play.fill")
                Text("CHALLENGE_PLAY")
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())

        case .failed(let message):
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                Text(message)
                    .lineLimit(1)
            }
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
        }
    }

    private func handleTap() {
        switch manager.state {
        case .notDownloaded, .failed:
            Task { await manager.download() }
        case .downloading:
            break
        case .downloaded:
            showVideoList = true
        }
    }
}

private struct ChallengePackYouTubeFallback: View {
    let bannerImage: BannerImageModel

    var body: some View {
        bannerImage.getImage()
            .resizable()
            .scaledToFit()
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(alignment: .bottomLeading) {
                Image(.youtubeLogo)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 18)
                    .padding()
            }
            .onTapGesture {
                if let url = URL(string: AppConfig.youtubeChallengeURL) {
                    UIApplication.shared.open(url)
                }
            }
    }
}
