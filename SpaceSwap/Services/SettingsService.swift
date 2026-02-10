//
//  SettingsService.swift
//  SpaceSwap
//
//  Created by 连晓彬 on 2026/2/9.
//

import Foundation
import Combine

public protocol SettingsServiceProtocol {
    var scanThreshold: Int64 { get set }
    var defaultCompressionPreset: String { get set }
    var autoPromptDelete: Bool { get set }
    var ignoredAssetIDs: [String] { get set }
}

public final class SettingsService: SettingsServiceProtocol, ObservableObject {
    private let userDefaults: UserDefaults
    private var isInitializing = true
    private let scanThresholdKey = "scanThreshold"
    private let defaultCompressionPresetKey = "defaultCompressionPreset"
    private let autoPromptDeleteKey = "autoPromptDelete"
    private let ignoredAssetIDsKey = "ignoredAssetIDs"
    
    @Published public var scanThreshold: Int64 {
        didSet {
            if !isInitializing {
                userDefaults.set(scanThreshold, forKey: scanThresholdKey)
            }
        }
    }
    
    @Published public var defaultCompressionPreset: String {
        didSet {
            if !isInitializing {
                userDefaults.set(defaultCompressionPreset, forKey: defaultCompressionPresetKey)
            }
        }
    }
    
    @Published public var autoPromptDelete: Bool {
        didSet {
            if !isInitializing {
                userDefaults.set(autoPromptDelete, forKey: autoPromptDeleteKey)
            }
        }
    }
    
    @Published public var ignoredAssetIDs: [String] {
        didSet {
            if !isInitializing {
                userDefaults.set(ignoredAssetIDs, forKey: ignoredAssetIDsKey)
            }
        }
    }
    
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        
        scanThreshold = max(Int64(userDefaults.integer(forKey: scanThresholdKey)), 50 * 1024 * 1024)
        
        defaultCompressionPreset = userDefaults.string(forKey: defaultCompressionPresetKey) ?? "H.265 High"
        
        if userDefaults.object(forKey: autoPromptDeleteKey) == nil {
            autoPromptDelete = true
        } else {
            autoPromptDelete = userDefaults.bool(forKey: autoPromptDeleteKey)
        }
        
        ignoredAssetIDs = userDefaults.array(forKey: ignoredAssetIDsKey) as? [String] ?? []
        
        isInitializing = false
    }
}