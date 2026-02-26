//
//  SettingsView.swift
//  SpaceSwap
//
//  Created by 连晓彬 on 2026/2/9.
//

import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel(settingsService: SettingsService())
    
    let compressionPresets = ["H.265 High", "H.265 Medium", "H.265 Low", "H.264 High", "H.264 Medium", "H.264 Low"]
    
    var body: some View {
        Form {
                Section(header: Text("Scan Settings")) {
                    VStack(alignment: .leading) {
                        Text("Minimum File Size: \(viewModel.formattedScanThreshold)")
                        Slider(value: Binding(
                            get: { Double(viewModel.scanThreshold) },
                            set: { viewModel.updateScanThreshold(Int64($0)) }
                        ), in: 50_000_000...1_000_000_000, step: 50_000_000)
                        Text("Files smaller than this size will be ignored during scanning.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text("Compression Settings")) {
                    Picker("Default Preset", selection: Binding(
                        get: { viewModel.defaultCompressionPreset },
                        set: { viewModel.updateDefaultCompressionPreset($0) }
                    )) {
                        ForEach(compressionPresets, id: \.self) { preset in
                            Text(preset)
                        }
                    }
                }
                
                Section(header: Text("Behavior")) {
                    Toggle("Auto-prompt to delete originals", isOn: Binding(
                        get: { viewModel.autoPromptDelete },
                        set: { viewModel.updateAutoPromptDelete($0) }
                    ))
                    Text("When enabled, the app will prompt to delete original files after successful compression.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section(header: Text("Ignored Assets")) {
                    if viewModel.ignoredAssetIDs.isEmpty {
                        Text("No assets ignored")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(viewModel.ignoredAssetIDs, id: \.self) { id in
                            HStack {
                                Text(id.prefix(8) + "...")
                                Spacer()
                                Button(action: {
                                    viewModel.removeIgnoredAssetID(id)
                                }) {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }
                    Button(action: {
                        // In a real app, this would open a picker to select assets to ignore
                        // For MVP, just add a dummy ID
                        viewModel.addIgnoredAssetID(UUID().uuidString)
                    }) {
                        Label("Add Ignored Asset", systemImage: "plus")
                    }
                }
            }
    }
}
