//
//  ChallengeVideoListView.swift
//  GustavTimer
//
//  Lists the downloaded Challenge pack videos and plays them with
//  AVPlayerViewController.
//

import SwiftUI
import AVKit
import GustavUICore

@available(iOS 26.0, *)
struct ChallengeVideoListView: View {
    let videoURLs: [URL]

    @State private var selectedURL: URL?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(videoURLs, id: \.self) { url in
                Button {
                    selectedURL = url
                } label: {
                    HStack {
                        Image(systemName: "play.rectangle.fill")
                            .foregroundStyle(Color.gustavPink)
                        Text(displayName(for: url))
                        Spacer()
                    }
                }
            }
            .navigationTitle(Text("CHALLENGE"))
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
            .fullScreenCover(item: Binding(
                get: { selectedURL.map(IdentifiableURL.init) },
                set: { selectedURL = $0?.url }
            )) { wrapper in
                ChallengeVideoPlayer(url: wrapper.url)
                    .ignoresSafeArea()
            }
        }
    }

    private func displayName(for url: URL) -> String {
        url.deletingPathExtension().lastPathComponent
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }
}

private struct IdentifiableURL: Identifiable {
    let url: URL
    var id: URL { url }
}

@available(iOS 26.0, *)
private struct ChallengeVideoPlayer: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = AVPlayer(url: url)
        controller.modalPresentationStyle = .fullScreen
        DispatchQueue.main.async {
            controller.player?.play()
        }
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {}
}
