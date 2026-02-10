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
    @Published var scannedAssets: [PhotoAsset] = []
    @Published var error: Error?
    @Published var showErrorAlert = false
    
    private let photoLibraryService: PhotoLibraryServiceProtocol
    private let settingsService: SettingsServiceProtocol
    
    private var scanTask: Task<Void, Never>?
    
    init(
        photoLibraryService: PhotoLibraryServiceProtocol = PhotoLibraryService(),
        settingsService: SettingsServiceProtocol = SettingsService()
    ) {
        self.photoLibraryService = photoLibraryService
        self.settingsService = settingsService
    }
    
    func startScan() {
        guard !isScanning else { return }
        
        isScanning = true
        scanProgress = 0.0
        scannedAssets = []
        error = nil
        
        scanTask = Task {
            do {
                let minSize = settingsService.scanThreshold
                let assets = try await photoLibraryService.fetchLargeVideos(minSize: minSize)
                
                // Simulate progress for UI feedback
                for (index, asset) in assets.enumerated() {
                    try Task.checkCancellation()
                    await MainActor.run {
                        self.scanProgress = Double(index + 1) / Double(assets.count)
                    }
                    try await Task.sleep(nanoseconds: 50_000_000) // 0.05s delay for smooth animation
                }
                
                await MainActor.run {
                    self.scannedAssets = assets.sorted { $0.fileSize > $1.fileSize }
                    self.isScanning = false
                    self.scanProgress = 1.0
                }
            } catch {
                await MainActor.run {
                    self.error = error
                    self.isScanning = false
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