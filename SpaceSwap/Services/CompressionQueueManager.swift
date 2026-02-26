//
//  CompressionQueueManager.swift
//  SpaceSwap
//
//  Created by Codex on 2026/2/26.
//

import Foundation
import Combine

enum CompressionQueueStatus: String {
    case queued
    case running
    case success
    case failed
    case cancelled

    var displayText: String {
        switch self {
        case .queued:
            return "Waiting"
        case .running:
            return "Compressing"
        case .success:
            return "Completed"
        case .failed:
            return "Failed"
        case .cancelled:
            return "Cancelled"
        }
    }
}

struct CompressionQueueEntry: Identifiable {
    var id: String { assetID }
    let assetID: String
    let asset: PhotoAsset
    let filename: String
    let originalSize: Int64
    let enqueuedAt: Date
    let quality: CompressionQuality

    var status: CompressionQueueStatus
    var progress: Double
    var updatedAt: Date
    var errorMessage: String?
    var record: CompressionRecord?

    var isTerminal: Bool {
        switch status {
        case .success, .failed, .cancelled:
            return true
        case .queued, .running:
            return false
        }
    }
}

@MainActor
final class CompressionQueueManager: ObservableObject {
    static let shared = CompressionQueueManager()

    let maxConcurrentTasks = 10

    @Published private(set) var entries: [String: CompressionQueueEntry] = [:]
    @Published private(set) var order: [String] = []

    private var pendingAssetIDs: [String] = []
    private var runningTasks: [String: Task<Void, Never>] = [:]

    private let photoLibraryService: PhotoLibraryServiceProtocol
    private let persistenceService: PersistenceServiceProtocol

    private init(
        photoLibraryService: PhotoLibraryServiceProtocol = PhotoLibraryService(),
        persistenceService: PersistenceServiceProtocol = PersistenceService()
    ) {
        self.photoLibraryService = photoLibraryService
        self.persistenceService = persistenceService
    }

    var runningCount: Int { runningTasks.count }
    var waitingCount: Int { pendingAssetIDs.count }

    var queueSnapshot: [CompressionQueueEntry] {
        order.compactMap { entries[$0] }
    }

    func entry(for assetID: String) -> CompressionQueueEntry? {
        entries[assetID]
    }

    @discardableResult
    func enqueue(asset: PhotoAsset, quality: CompressionQuality) -> Bool {
        guard entries[asset.id] == nil else {
            return false
        }

        let now = Date()
        entries[asset.id] = CompressionQueueEntry(
            assetID: asset.id,
            asset: asset,
            filename: asset.filename,
            originalSize: asset.fileSize,
            enqueuedAt: now,
            quality: quality,
            status: .queued,
            progress: 0.0,
            updatedAt: now,
            errorMessage: nil,
            record: nil
        )
        order.insert(asset.id, at: 0)
        pendingAssetIDs.append(asset.id)
        drainQueue()
        return true
    }

    func cancel(assetID: String) {
        guard var entry = entries[assetID] else { return }

        switch entry.status {
        case .queued:
            pendingAssetIDs.removeAll { $0 == assetID }
            entry.status = .cancelled
            entry.updatedAt = Date()
            entry.errorMessage = "Cancelled before start."
            entries[assetID] = entry
        case .running:
            runningTasks[assetID]?.cancel()
        case .success, .failed, .cancelled:
            break
        }
    }

    private func drainQueue() {
        while runningTasks.count < maxConcurrentTasks, let nextAssetID = pendingAssetIDs.first {
            pendingAssetIDs.removeFirst()
            startTask(assetID: nextAssetID)
        }
    }

    private func startTask(assetID: String) {
        guard entries[assetID] != nil else { return }

        runningTasks[assetID] = Task { [weak self] in
            guard let self else { return }
            await self.executeCompression(assetID: assetID)
        }
    }

    private func executeCompression(assetID: String) async {
        guard var entry = entries[assetID] else {
            runningTasks[assetID] = nil
            drainQueue()
            return
        }

        entry.status = .running
        entry.progress = max(entry.progress, 0.01)
        entry.updatedAt = Date()
        entries[assetID] = entry

        do {
            let result = try await photoLibraryService.compressVideo(entry.asset, quality: entry.quality) { [weak self] progress in
                Task { @MainActor [weak self] in
                    self?.updateProgress(assetID: assetID, progress: progress)
                }
            }

            let record = CompressionRecord(
                originalAssetID: entry.asset.id,
                compressedAssetID: result.compressedAssetId,
                date: Date(),
                originalSize: entry.asset.fileSize,
                compressedSize: result.compressedSize,
                compressionRatio: Double(result.compressedSize) / Double(entry.asset.fileSize),
                quality: entry.quality.rawValue,
                status: 1,
                isAssetDeleted: false
            )

            try await persistenceService.save(record: record)
            completeSuccess(assetID: assetID, record: record)
        } catch is CancellationError {
            completeCancelled(assetID: assetID)
        } catch {
            completeFailed(assetID: assetID, error: error)
        }

        runningTasks[assetID] = nil
        drainQueue()
    }

    private func updateProgress(assetID: String, progress: Double) {
        guard var entry = entries[assetID], entry.status == .running else { return }
        entry.progress = min(max(progress, 0.0), 1.0)
        entry.updatedAt = Date()
        entries[assetID] = entry
    }

    private func completeSuccess(assetID: String, record: CompressionRecord) {
        guard var entry = entries[assetID] else { return }
        entry.status = .success
        entry.progress = 1.0
        entry.updatedAt = Date()
        entry.record = record
        entry.errorMessage = nil
        entries[assetID] = entry
    }

    private func completeCancelled(assetID: String) {
        guard var entry = entries[assetID] else { return }
        entry.status = .cancelled
        entry.updatedAt = Date()
        entry.errorMessage = "Compression cancelled."
        entries[assetID] = entry
    }

    private func completeFailed(assetID: String, error: Error) {
        guard var entry = entries[assetID] else { return }
        entry.status = .failed
        entry.updatedAt = Date()
        entry.errorMessage = error.localizedDescription
        entries[assetID] = entry
    }
}
