//
//  HomeView.swift
//  SpaceSwap
//
//  Created by 连晓彬 on 2026/2/9.
//

import SwiftUI
import Photos

public struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @State private var sortOption: SortOption = .sizeDescending
    
    enum SortOption: String, CaseIterable {
        case sizeDescending = "Size (Large First)"
        case sizeAscending = "Size (Small First)"
        case dateNewest = "Date (Newest)"
        case dateOldest = "Date (Oldest)"
    }
    
    var sortedAssets: [PhotoAsset] {
        switch sortOption {
        case .sizeDescending:
            return viewModel.scannedAssets.sorted { $0.fileSize > $1.fileSize }
        case .sizeAscending:
            return viewModel.scannedAssets.sorted { $0.fileSize < $1.fileSize }
        case .dateNewest:
            return viewModel.scannedAssets.sorted { $0.phAsset.creationDate ?? Date.distantPast > $1.phAsset.creationDate ?? Date.distantPast }
        case .dateOldest:
            return viewModel.scannedAssets.sorted { $0.phAsset.creationDate ?? Date.distantPast < $1.phAsset.creationDate ?? Date.distantPast }
        }
    }
    
    public var body: some View {
        NavigationView {
        NavigationView {
            VStack(spacing: 0) {
                VStack(spacing: 16) {
                    Text("Space Swap")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    if viewModel.isScanning {
                        VStack(spacing: 8) {
                            ProgressView("Scanning videos...", value: viewModel.scanProgress)
                                .progressViewStyle(.linear)
                            Text("\(Int(viewModel.scanProgress * 100))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                    } else if !viewModel.scannedAssets.isEmpty {
                        VStack(spacing: 8) {
                            Text("\(viewModel.scannedAssets.count) large videos found")
                                .font(.headline)
                            Text("Potential savings: \(viewModel.potentialSavings.formattedBytes)")
                                .font(.subheadline)
                                .foregroundColor(.green)
                        }
                        .padding()
                    } else {
                        VStack(spacing: 16) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            Text("Scan your photo library for large videos")
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary)
                        }
                        .padding()
        }
    }
}
                
                // Scan Button
                if !viewModel.isScanning {
                    Button(action: {
                        Task {
                            await viewModel.startScan()
                        }
                    }) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                            Text(viewModel.scannedAssets.isEmpty ? "Start Scan" : "Scan Again")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .disabled(viewModel.isScanning)
                }
                
                // Sort Picker
                if !viewModel.scannedAssets.isEmpty && !viewModel.isScanning {
                    Picker("Sort by", selection: $sortOption) {
                        ForEach(SortOption.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                    .padding(.horizontal)
                }
                
                // Results List
                if !viewModel.scannedAssets.isEmpty {
                    List(sortedAssets) { asset in
                        NavigationLink(destination: CompressionView(asset: asset)) {
                            HStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 60, height: 60)
                                    .overlay(
                                        Image(systemName: "video.fill")
                                            .foregroundColor(.white)
                                    )
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Video")
                                        .font(.headline)
                                    Text(asset.fileSize.formattedBytes)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Text("Duration: \(asset.duration.formattedDuration)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if asset.isCloudAsset {
                                    Image(systemName: "icloud")
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    }
                    .listStyle(.plain)
                } else if viewModel.isScanning {
                    Spacer()
                } else {
                    Spacer()
                }
            }
            .navigationBarHidden(true)
            .alert("Scan Error", isPresented: $viewModel.showErrorAlert, actions: {
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
}

#Preview {
    HomeView()
}