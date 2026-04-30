//
//  ChallengePackExtension.swift
//  ChallengePackExtension
//
//  Background Assets extension for the Gustav Timer challenge pack.
//  iOS 26+ delivers downloads to the app group container so the host
//  app (and its Watch counterpart) can read videos offline.
//

import Foundation
import BackgroundAssets
import os

@available(iOS 26.0, *)
@main
struct ChallengePackExtension: BADownloaderExtension {

    private static let appGroupID = "group.cz.daliborjanecek.GustavTimer"
    private static let packIdentifier = "cz.daliborjanecek.GustavTimer.ChallengePack"
    private static let logger = Logger(
        subsystem: "cz.daliborjanecek.GustavTimer.ChallengePackExtension",
        category: "Downloader"
    )

    func applicationDidInstall(_ metadata: BAAppExtensionInfo) {
        // The pack is on-demand only — nothing to schedule on install.
        Self.logger.log("App installed; ChallengePack is on-demand.")
    }

    func applicationDidUpdate(_ metadata: BAAppExtensionInfo) {
        Self.logger.log("App updated; ChallengePack remains on-demand.")
    }

    func backgroundDownload(
        _ failedDownload: BADownload,
        failedWithError error: Error
    ) {
        Self.logger.error(
            "Download \(failedDownload.identifier, privacy: .public) failed: \(error.localizedDescription, privacy: .public)"
        )
    }

    func backgroundDownload(_ finishedDownload: BADownload, finishedWithFileURL fileURL: URL) {
        guard finishedDownload.identifier == Self.packIdentifier else { return }

        let fm = FileManager.default
        guard let container = fm.containerURL(
            forSecurityApplicationGroupIdentifier: Self.appGroupID
        ) else {
            Self.logger.error("App group container missing; cannot stage challenge pack.")
            return
        }

        let destination = container.appendingPathComponent("ChallengePack", isDirectory: true)

        do {
            if fm.fileExists(atPath: destination.path) {
                try fm.removeItem(at: destination)
            }
            try fm.createDirectory(at: destination, withIntermediateDirectories: true)
            try unpack(zipAt: fileURL, into: destination)
            Self.logger.log("Challenge pack staged at \(destination.path, privacy: .public).")
        } catch {
            Self.logger.error("Failed to stage challenge pack: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Asset packs are delivered as a single archive; expand it into the
    /// app group container. For development the archive structure mirrors
    /// `ChallengePackAssets/` in the repo.
    private func unpack(zipAt source: URL, into destination: URL) throws {
        // Apple's BA framework hands us the unpacked asset pack directory on
        // iOS 26, so simply move/copy the contents over. If the source is a
        // directory, copy each entry; if it's a single file, drop it in.
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: source.path, isDirectory: &isDir) else { return }

        if isDir.boolValue {
            for entry in try fm.contentsOfDirectory(atPath: source.path) {
                let from = source.appendingPathComponent(entry)
                let to = destination.appendingPathComponent(entry)
                if fm.fileExists(atPath: to.path) {
                    try fm.removeItem(at: to)
                }
                try fm.copyItem(at: from, to: to)
            }
        } else {
            let to = destination.appendingPathComponent(source.lastPathComponent)
            if fm.fileExists(atPath: to.path) {
                try fm.removeItem(at: to)
            }
            try fm.copyItem(at: source, to: to)
        }
    }
}
