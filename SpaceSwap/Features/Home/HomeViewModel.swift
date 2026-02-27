//
//  HomeViewModel.swift
//  SpaceSwap
//
//  Created by 连晓彬 on 2026/2/9.
//

import SwiftUI
import Combine

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var isScanning = false
    @Published var scanProgress: Double = 0.0
    @Published var scanningMatchedCount: Int = 0
    @Published var scannedAssets: [PhotoAsset] = []
    @Published var compressedCopyRecordsByAssetID: [String: CompressionRecord] = [:]
    @Published var error: Error?
    @Published var showErrorAlert = false
    
    private let photoLibraryService: PhotoLibraryServiceProtocol
    private let settingsService: SettingsServiceProtocol
    private let persistenceService: PersistenceServiceProtocol
    
    private var scanTask: Task<Void, Never>?
    
    init(
        photoLibraryService: PhotoLibraryServiceProtocol = PhotoLibraryService(),
        settingsService: SettingsServiceProtocol = SettingsService(),
        persistenceService: PersistenceServiceProtocol = PersistenceService()
    ) {
        self.photoLibraryService = photoLibraryService
        self.settingsService = settingsService
        self.persistenceService = persistenceService
    }
    
    func startScan() {
        guard !isScanning else { return }
        
        isScanning = true
        scanProgress = 0.0
        scanningMatchedCount = 0
        scannedAssets = []
        compressedCopyRecordsByAssetID = [:]
        error = nil
        
        scanTask = Task {
            do {
                let minSize = settingsService.scanThreshold
                let assets = try await photoLibraryService.fetchLargeVideos(minSize: minSize)
                let records = try await persistenceService.fetchAll()
                let successfulRecords = records.filter { $0.status == 1 }

                let successfulOriginalIDs = Set(successfulRecords.map { $0.originalAssetID })
                let compressedRecordsByID = Dictionary(uniqueKeysWithValues: successfulRecords.map { ($0.compressedAssetID, $0) })

                let filteredAssets = assets.filter { !successfulOriginalIDs.contains($0.id) }
                let compressedCopyRecordsByAssetID = filteredAssets.reduce(into: [String: CompressionRecord]()) { output, asset in
                    if let record = compressedRecordsByID[asset.id] {
                        output[asset.id] = record
                    }
                }
                
                // Simulate progress for UI feedback
                for (index, _) in filteredAssets.enumerated() {
                    try Task.checkCancellation()
                    await MainActor.run {
                        self.scanProgress = filteredAssets.isEmpty ? 1.0 : (Double(index + 1) / Double(filteredAssets.count))
                        self.scanningMatchedCount = index + 1
                    }
                    try await Task.sleep(nanoseconds: 50_000_000) // 0.05s delay for smooth animation
                }
                
                await MainActor.run {
                    self.scannedAssets = filteredAssets.sorted { $0.fileSize > $1.fileSize }
                    self.compressedCopyRecordsByAssetID = compressedCopyRecordsByAssetID
                    self.isScanning = false
                    self.scanProgress = 1.0
                }
            } catch {
                if error is CancellationError {
                    return
                }
                await MainActor.run {
                    self.error = error
                    self.isScanning = false
                    self.scanningMatchedCount = 0
                    self.showErrorAlert = true
                }
            }
        }
    }
    
    func cancelScan() {
        scanTask?.cancel()
        scanTask = nil
        isScanning = false
        scanProgress = 0.0
        scanningMatchedCount = 0
        error = nil
    }
    
    func clearResults() {
        scannedAssets = []
        error = nil
        showErrorAlert = false
    }
    
    var totalScannedSize: Int64 {
        scannedAssets.reduce(0) { $0 + $1.fileSize }
    }
    
    var potentialSavings: Int64 {
        // Estimate 50% compression for H.265
        Int64(Double(totalScannedSize) * 0.5)
    }
}
