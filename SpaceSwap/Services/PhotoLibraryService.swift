//
//  PhotoLibraryService.swift
//  SpaceSwap
//
//  Created by 连晓彬 on 2026/2/9.
//

import Photos
import Foundation

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

protocol PhotoLibraryServiceProtocol {
    func fetchLargeVideos(minSize: Int64) async throws -> [PhotoAsset]
    func deleteAsset(_ asset: PhotoAsset) async throws
    func saveVideo(from url: URL) async throws -> String
    func compressVideo(_ asset: PhotoAsset, quality: CompressionQuality, progressHandler: @escaping (Double) -> Void) async throws -> CompressionResult
}

final class PhotoLibraryService: PhotoLibraryServiceProtocol {
    func fetchLargeVideos(minSize: Int64) async throws -> [PhotoAsset] {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        guard status == .authorized || status == .limited else {
            throw NSError(domain: "PhotoLibrary", code: 1, userInfo: [NSLocalizedDescriptionKey: "Photo library access denied"])
        }
        
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
        try await withCheckedThrowingContinuation { continuation in
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
            } completionHandler: { success, error in
                if success {
                    continuation.resume(returning: "saved-video-id")
                } else {
                    continuation.resume(throwing: error ?? NSError(domain: "Save", code: 1))
                }
            }
        }
    }
    
    func compressVideo(_ asset: PhotoAsset, quality: CompressionQuality, progressHandler: @escaping (Double) -> Void) async throws -> CompressionResult {
        // Simulate compression process
        for progress in stride(from: 0.0, through: 1.0, by: 0.1) {
            try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
            progressHandler(progress)
        }
        
        // Calculate compressed size based on quality
        let compressionRatio: Double
        switch quality {
        case .low: compressionRatio = 0.3
        case .medium: compressionRatio = 0.5
        case .high: compressionRatio = 0.7
        case .original: compressionRatio = 1.0
        }
        
        let compressedSize = Int64(Double(asset.fileSize) * compressionRatio)
        let compressedAssetId = "compressed-\(asset.id)"
        
        return CompressionResult(compressedAssetId: compressedAssetId, compressedSize: compressedSize)
    }
}
