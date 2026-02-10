//
//  CompressionView.swift
//  SpaceSwap
//
//  Created by 连晓彬 on 2026/2/9.
//

import SwiftUI

struct CompressionView: View {
    let asset: PhotoAsset
    @StateObject private var viewModel = CompressionViewModel()
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedQuality: CompressionQuality = .medium
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Asset Preview
                VStack(spacing: 16) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 200)
                        .overlay(
                            VStack(spacing: 8) {
                                Image(systemName: "video.fill")
                                    .font(.system(size: 48))
                                    .foregroundColor(.white)
                                Text("Video Preview")
                                    .foregroundColor(.white)
                                    .font(.headline)
                            }
                        )
                    
                    VStack(spacing: 8) {
                        Text("Video Details")
                            .font(.headline)
                        Text(asset.fileSize.formattedBytes)
                            .font(.subheadline)
                        Text("Duration: \(asset.duration.formattedDuration)")
                            .font(.subheadline)
                    }
                }
                .padding(.horizontal)
                
                // Compression Settings
                VStack(spacing: 16) {
                    Text("Compression Quality")
                        .font(.headline)
                    
                    Picker("Quality", selection: $selectedQuality) {
                        ForEach(CompressionQuality.allCases, id: \.self) { quality in
                            Text(quality.rawValue).tag(quality)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Estimated Results:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Text("Original: \(asset.fileSize.formattedBytes)")
                            Spacer()
                            Text("Estimated: ~\(estimatedCompressedSize(asset.fileSize, quality: selectedQuality).formattedBytes)")
                        }
                        .font(.caption)
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Compression Button
                if !viewModel.isCompressing {
                    Button(action: {
                        Task {
                            await viewModel.startCompression(for: asset, quality: selectedQuality)
                        }
                    }) {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("Start Compression")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                } else {
                    // Progress View
                    VStack(spacing: 16) {
                        ProgressView("Compressing...", value: viewModel.compressionProgress)
                            .progressViewStyle(.linear)
                        
                        Text("\(Int(viewModel.compressionProgress * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if let currentAsset = viewModel.currentAsset {
                            Text("Processing: \(currentAsset.id)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Button("Cancel") {
                            viewModel.cancelCompression()
                        }
                        .foregroundColor(.red)
                    }
                    .padding(.horizontal)
                }
                
                // Results
                if let result = viewModel.compressionResult {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.green)
                        
                        Text("Compression Complete!")
                            .font(.headline)
                        
                        VStack(spacing: 8) {
                            HStack {
                                Text("Original Size:")
                                Spacer()
                                Text(result.originalSize.formattedBytes)
                            }
                            HStack {
                                Text("Compressed Size:")
                                Spacer()
                                Text(result.compressedSize.formattedBytes)
                            }
                            HStack {
                                Text("Space Saved:")
                                Spacer()
                                Text((result.originalSize - result.compressedSize).formattedBytes)
                                    .foregroundColor(.green)
                            }
                        }
                        .font(.subheadline)
                        
                        Button("Done") {
                            dismiss()
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.green)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle("Compress Video")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Compression Error", isPresented: .constant(viewModel.error != nil), actions: {
                Button("OK") {
                    viewModel.clearResults()
                }
            }, message: {
                if let error = viewModel.error {
                    Text(error.localizedDescription)
                }
            })
        }
    }
    
    private func estimatedCompressedSize(_ originalSize: Int64, quality: CompressionQuality) -> Int64 {
        let ratio: Double
        switch quality {
        case .low: ratio = 0.3
        case .medium: ratio = 0.5
        case .high: ratio = 0.7
        case .original: ratio = 1.0
        }
        return Int64(Double(originalSize) * ratio)
    }
}