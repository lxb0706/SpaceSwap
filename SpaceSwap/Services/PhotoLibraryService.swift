//
//  PhotoLibraryService.swift
//  SpaceSwap
//
//  Created by 连晓彬 on 2026/2/9.
//

import Photos
import Foundation
@preconcurrency import AVFoundation

enum CompressionQuality: String, CaseIterable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case original = "Original"
}

struct CompressionResult {
    let compressedAssetId: String
    let compressedSize: Int64
}

enum PhotoLibraryError: LocalizedError {
    case accessDenied
    case exportSessionCreationFailed
    case assetLoadFailed
    case needsICloudDownload
    case unsupportedOutputType
    case failedToResolveCreatedAssetID

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Photo library access denied"
        case .exportSessionCreationFailed:
            return "Failed to create export session"
        case .assetLoadFailed:
            return "Failed to load video asset"
        case .needsICloudDownload:
            return "Asset needs to be downloaded from iCloud"
        case .unsupportedOutputType:
            return "No supported output file type found for export"
        case .failedToResolveCreatedAssetID:
            return "Failed to resolve newly created asset identifier"
        }
    }
}

protocol PhotoLibraryServiceProtocol {
    func fetchLargeVideos(minSize: Int64) async throws -> [PhotoAsset]
    func deleteAsset(_ asset: PhotoAsset) async throws
    func saveVideo(from url: URL) async throws -> String
    func compressVideo(_ asset: PhotoAsset, quality: CompressionQuality, progressHandler: @escaping (Double) -> Void) async throws -> CompressionResult
}

final class PhotoLibraryService: PhotoLibraryServiceProtocol {
    private var currentExportSession: AVAssetExportSession?
    private var currentImageRequestID: PHImageRequestID?

    func fetchLargeVideos(minSize: Int64) async throws -> [PhotoAsset] {
        try await ensureAuthorization()
        
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let fetchOptions = PHFetchOptions()
                fetchOptions.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.video.rawValue)
                fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

                let fetchResult = PHAsset.fetchAssets(with: fetchOptions)
                var assets: [PhotoAsset] = []

                fetchResult.enumerateObjects { asset, _, _ in
                    if let resource = PHAssetResource.assetResources(for: asset).first(where: { $0.type == .video }) {
                        let size = (resource.value(forKey: "fileSize") as? NSNumber)?.int64Value ?? 0
                        if size >= minSize {
                            let photoAsset = PhotoAsset(phAsset: asset, fileSize: size)
                            assets.append(photoAsset)
                        }
                    }
                }

                continuation.resume(returning: assets)
            }
        }
    }
    
    func deleteAsset(_ asset: PhotoAsset) async throws {
        try await withCheckedThrowingContinuation { continuation in
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.deleteAssets([asset.phAsset] as NSArray)
            } completionHandler: { success, error in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: error ?? NSError(domain: "Delete", code: 1))
                }
            }
        }
    }
    
    func saveVideo(from url: URL) async throws -> String {
        try await ensureAuthorization()

        return try await withCheckedThrowingContinuation { continuation in
            var createdAssetID: String?
            PHPhotoLibrary.shared().performChanges {
                let request = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
                createdAssetID = request?.placeholderForCreatedAsset?.localIdentifier
            } completionHandler: { success, error in
                if success {
                    if let createdAssetID {
                        continuation.resume(returning: createdAssetID)
                    } else {
                        continuation.resume(throwing: PhotoLibraryError.failedToResolveCreatedAssetID)
                    }
                } else {
                    continuation.resume(throwing: error ?? NSError(domain: "Save", code: 1))
                }
            }
        }
    }
    
    func compressVideo(_ asset: PhotoAsset, quality: CompressionQuality, progressHandler: @escaping (Double) -> Void) async throws -> CompressionResult {
        try await ensureAuthorization()
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")

        return try await withTaskCancellationHandler(operation: {
            defer {
                try? FileManager.default.removeItem(at: outputURL)
            }

            try Task.checkCancellation()

            let avAsset = try await requestAVAsset(for: asset.phAsset) { progress in
                progressHandler(progress * 0.3)
            }

            try Task.checkCancellation()

            let exportedURL = try await exportAsset(
                avAsset,
                quality: quality,
                preferredOutputURL: outputURL
            ) { progress in
                progressHandler(0.3 + (Double(progress) * 0.7))
            }

            let compressedSize = try fileSize(at: exportedURL)
            let compressedAssetId = try await saveVideo(from: exportedURL)

            progressHandler(1.0)
            return CompressionResult(compressedAssetId: compressedAssetId, compressedSize: compressedSize)
        }, onCancel: {
            if let currentImageRequestID {
                PHImageManager.default().cancelImageRequest(currentImageRequestID)
                self.currentImageRequestID = nil
            }
            currentExportSession?.cancelExport()
            currentExportSession = nil
        })
    }

    private func ensureAuthorization() async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        guard status == .authorized || status == .limited else {
            throw PhotoLibraryError.accessDenied
        }
    }

    private func requestAVAsset(
        for asset: PHAsset,
        progressHandler: @escaping (Double) -> Void
    ) async throws -> AVAsset {
        do {
            return try await requestAVAsset(for: asset, isNetworkAccessAllowed: false, progressHandler: nil)
        } catch PhotoLibraryError.needsICloudDownload {
            return try await requestAVAsset(for: asset, isNetworkAccessAllowed: true, progressHandler: progressHandler)
        }
    }

    private func requestAVAsset(
        for asset: PHAsset,
        isNetworkAccessAllowed: Bool,
        progressHandler: ((Double) -> Void)?
    ) async throws -> AVAsset {
        try await withCheckedThrowingContinuation { continuation in
            let options = PHVideoRequestOptions()
            options.isNetworkAccessAllowed = isNetworkAccessAllowed
            options.deliveryMode = .highQualityFormat
            options.version = .current
            options.progressHandler = { progress, _, _, _ in
                guard let progressHandler else { return }
                DispatchQueue.main.async {
                    progressHandler(progress)
                }
            }

            let requestID = PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, info in
                self.currentImageRequestID = nil

                if let avAsset {
                    continuation.resume(returning: avAsset)
                    return
                }

                if (info?[PHImageCancelledKey] as? Bool) == true {
                    continuation.resume(throwing: CancellationError())
                    return
                }

                let isInCloud = (info?[PHImageResultIsInCloudKey] as? Bool) ?? false
                if isInCloud && !isNetworkAccessAllowed {
                    continuation.resume(throwing: PhotoLibraryError.needsICloudDownload)
                    return
                }

                if let error = info?[PHImageErrorKey] as? Error {
                    continuation.resume(throwing: error)
                    return
                }

                continuation.resume(throwing: PhotoLibraryError.assetLoadFailed)
            }

            self.currentImageRequestID = requestID
        }
    }

    private func exportAsset(
        _ asset: AVAsset,
        quality: CompressionQuality,
        preferredOutputURL: URL,
        progressHandler: @escaping (Float) -> Void
    ) async throws -> URL {
        let preset = await selectPreset(for: asset, quality: quality)
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: preset) else {
            throw PhotoLibraryError.exportSessionCreationFailed
        }

        try? FileManager.default.removeItem(at: preferredOutputURL)
        currentExportSession = exportSession

        var outputURL = preferredOutputURL
        let outputFileType: AVFileType
        if exportSession.supportedFileTypes.contains(.mp4) {
            outputFileType = .mp4
        } else if exportSession.supportedFileTypes.contains(.mov) {
            outputURL = preferredOutputURL.deletingPathExtension().appendingPathExtension("mov")
            try? FileManager.default.removeItem(at: outputURL)
            outputFileType = .mov
        } else {
            currentExportSession = nil
            throw PhotoLibraryError.unsupportedOutputType
        }

        let progressTask = Task {
            while !Task.isCancelled {
                progressHandler(exportSession.progress)
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
        }

        defer {
            progressTask.cancel()
            currentExportSession = nil
        }

        try await exportSession.export(to: outputURL, as: outputFileType)

        progressHandler(1.0)
        return outputURL
    }

    private func selectPreset(for asset: AVAsset, quality: CompressionQuality) async -> String {
        let highPreferences = [
            AVAssetExportPresetHEVC1920x1080,
            AVAssetExportPresetHighestQuality,
            AVAssetExportPreset1920x1080,
            AVAssetExportPreset1280x720,
            AVAssetExportPresetMediumQuality
        ]

        let mediumPreferences = [
            AVAssetExportPresetHEVC1920x1080,
            AVAssetExportPresetMediumQuality,
            AVAssetExportPreset1280x720,
            AVAssetExportPreset640x480,
            AVAssetExportPresetLowQuality
        ]

        let lowPreferences = [
            AVAssetExportPresetLowQuality,
            AVAssetExportPreset640x480,
            AVAssetExportPresetMediumQuality
        ]

        let originalPreferences = [
            AVAssetExportPresetPassthrough,
            AVAssetExportPresetHighestQuality
        ]

        let candidates: [String]
        switch quality {
        case .high:
            candidates = highPreferences
        case .medium:
            candidates = mediumPreferences
        case .low:
            candidates = lowPreferences
        case .original:
            candidates = originalPreferences
        }

        for preset in candidates {
            if await isPresetCompatible(preset, with: asset) {
                return preset
            }
        }

        return AVAssetExportPresetMediumQuality
    }

    private func isPresetCompatible(_ preset: String, with asset: AVAsset) async -> Bool {
        await withCheckedContinuation { continuation in
            AVAssetExportSession.determineCompatibility(
                ofExportPreset: preset,
                with: asset,
                outputFileType: nil
            ) { compatible in
                continuation.resume(returning: compatible)
            }
        }
    }

    private func fileSize(at url: URL) throws -> Int64 {
        let values = try url.resourceValues(forKeys: [.fileSizeKey])
        return Int64(values.fileSize ?? 0)
    }
}
