//
//  ChallengePackManager.swift
//  GustavTimer
//
//  Manages on-demand download of the Challenge video pack via Apple
//  Background Assets (BADownloadManager). iOS 26+ only.
//

import Foundation
#if canImport(BackgroundAssets)
import BackgroundAssets
#endif

@available(iOS 26.0, *)
@MainActor
final class ChallengePackManager: ObservableObject {

    enum State: Equatable {
        case notDownloaded
        case downloading(progress: Double)
        case downloaded
        case failed(message: String)
    }

    /// App Group used by the app and the Background Assets extension.
    static let appGroupID = "group.cz.daliborjanecek.GustavTimer"

    /// Identifier of the asset pack as published in App Store Connect.
    static let packIdentifier = "cz.daliborjanecek.GustavTimer.ChallengePack"

    /// Total bytes of the pack (used for download size estimation in UI).
    static let approximateByteSize: Int64 = 220_000_000

    static let videoCount = 12

    @Published private(set) var state: State = .notDownloaded

    private var progressObservation: NSKeyValueObservation?

    init() {
        refreshStateFromDisk()
    }

    deinit {
        progressObservation?.invalidate()
    }

    // MARK: - Public API

    func download() async {
        guard case .notDownloaded = state else { return }
        guard #available(iOS 26.0, *) else { return }

        do {
            let manager = BADownloadManager.shared
            let download = BAAppGroupDownload(
                identifier: Self.packIdentifier,
                essential: false,
                fileSize: Self.approximateByteSize,
                appGroupIdentifier: Self.appGroupID,
                priority: .default
            )

            state = .downloading(progress: 0)
            observeProgress(of: download)
            try await manager.startForegroundDownload(download)
        } catch {
            state = .failed(message: error.localizedDescription)
        }
    }

    func cancelDownload() {
        guard case .downloading = state else { return }
        guard #available(iOS 26.0, *) else { return }

        let manager = BADownloadManager.shared
        Task {
            let active = (try? await manager.fetchCurrentDownloads()) ?? []
            for download in active where download.identifier == Self.packIdentifier {
                try? manager.cancel(download)
            }
            await MainActor.run {
                self.progressObservation?.invalidate()
                self.progressObservation = nil
                self.state = .notDownloaded
            }
        }
    }

    func deletePack() {
        guard let directory = Self.packDirectory() else { return }
        try? FileManager.default.removeItem(at: directory)
        progressObservation?.invalidate()
        progressObservation = nil
        state = .notDownloaded
    }

    /// All downloaded video file URLs, sorted by name.
    func videoURLs() -> [URL] {
        guard let directory = Self.packDirectory() else { return [] }
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )) ?? []
        return contents
            .filter { ["mp4", "mov", "m4v"].contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    // MARK: - Internal

    private func refreshStateFromDisk() {
        if !videoURLs().isEmpty {
            state = .downloaded
        } else {
            state = .notDownloaded
        }
    }

    @available(iOS 26.0, *)
    private func observeProgress(of download: BADownload) {
        progressObservation?.invalidate()
        progressObservation = download.progress.observe(\.fractionCompleted, options: [.initial, .new]) { [weak self] progress, _ in
            let fraction = progress.fractionCompleted
            Task { @MainActor in
                guard let self else { return }
                if fraction >= 1.0 {
                    self.refreshStateFromDisk()
                } else {
                    self.state = .downloading(progress: fraction)
                }
            }
        }
    }

    /// Local URL (within the app group container) where the pack files live
    /// after the Background Assets extension has staged them.
    static func packDirectory() -> URL? {
        let fm = FileManager.default
        guard let container = fm.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) else { return nil }
        let dir = container.appendingPathComponent("ChallengePack", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
}
