//
//  SettingsViewModel.swift
//  SpaceSwap
//
//  Created by 连晓彬 on 2026/2/9.
//

import Foundation
import Combine

public class SettingsViewModel: ObservableObject {
    private var settingsService: SettingsServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    // Published properties for binding
    @Published public var scanThreshold: Int64
    @Published public var defaultCompressionPreset: String
    @Published public var autoPromptDelete: Bool
    @Published public var ignoredAssetIDs: [String]
    
    public init(settingsService: SettingsServiceProtocol) {
        self.settingsService = settingsService
        
        // Initialize from service
        self.scanThreshold = settingsService.scanThreshold
        self.defaultCompressionPreset = settingsService.defaultCompressionPreset
        self.autoPromptDelete = settingsService.autoPromptDelete
        self.ignoredAssetIDs = settingsService.ignoredAssetIDs
    }
    
    // Methods to update settings
    func updateScanThreshold(_ value: Int64) {
        settingsService.scanThreshold = value
        scanThreshold = value
    }
    
    func updateDefaultCompressionPreset(_ preset: String) {
        settingsService.defaultCompressionPreset = preset
        defaultCompressionPreset = preset
    }
    
    func updateAutoPromptDelete(_ value: Bool) {
        settingsService.autoPromptDelete = value
        autoPromptDelete = value
    }
    
    func addIgnoredAssetID(_ id: String) {
        var ids = settingsService.ignoredAssetIDs
        if !ids.contains(id) {
            ids.append(id)
            settingsService.ignoredAssetIDs = ids
            ignoredAssetIDs = ids
        }
    }
    
    func removeIgnoredAssetID(_ id: String) {
        var ids = settingsService.ignoredAssetIDs
        ids.removeAll { $0 == id }
        settingsService.ignoredAssetIDs = ids
        ignoredAssetIDs = ids
    }
    
    // Helper for formatted threshold
    var formattedScanThreshold: String {
        ByteCountFormatter.string(fromByteCount: scanThreshold, countStyle: .file)
    }
}