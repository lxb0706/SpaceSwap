//
//  CompressionViewModel.swift
//  SpaceSwap
//
//  Created by 连晓彬 on 2026/2/9.
//

import SwiftUI
import Combine

@MainActor
final class CompressionViewModel: ObservableObject {
    @Published var isCompressing = false
    @Published var compressionProgress: Double = 0.0
    @Published var currentAsset: PhotoAsset?
    @Published var error: Error?
    @Published var compressionResult: CompressionRecord?
    
    private let photoLibraryService: PhotoLibraryServiceProtocol
    private let persistenceService: PersistenceServiceProtocol
    
    private var compressionTask: Task<Void, Never>?
    
    init(
        photoLibraryService: PhotoLibraryServiceProtocol = PhotoLibraryService(),
        persistenceService: PersistenceServiceProtocol = PersistenceService()
    ) {
        self.photoLibraryService = photoLibraryService
        self.persistenceService = persistenceService
    }
    
    func startCompression(for asset: PhotoAsset, quality: CompressionQuality = .medium) async {
        guard !isCompressing else { return }
        
        isCompressing = true
        compressionProgress = 0.0
        currentAsset = asset
        error = nil
        compressionResult = nil
        
        compressionTask = Task {
            do {
                let result = try await photoLibraryService.compressVideo(asset, quality: quality) { progress in
                    Task { @MainActor in
                        self.compressionProgress = progress
                    }
                }
                
                let record = CompressionRecordFactory.make(
                    originalAssetID: asset.id,
                    compressedAssetID: result.compressedAssetId,
                    originalFilename: asset.filename,
                    date: Date(),
                    originalSize: asset.fileSize,
                    compressedSize: result.compressedSize,
                    quality: quality.rawValue,
                    status: 1, // Success
                    isAssetDeleted: false
                )
                
                try await persistenceService.save(record: record)
                
                compressionResult = record
            } catch {
                self.error = error
            }
            
            isCompressing = false
            currentAsset = nil
            compressionProgress = 0.0
        }
    }
    
    func cancelCompression() {
        compressionTask?.cancel()
        compressionTask = nil
        isCompressing = false
        currentAsset = nil
        compressionProgress = 0.0
    }
    
    func clearResults() {
        error = nil
        compressionResult = nil
    }
}
