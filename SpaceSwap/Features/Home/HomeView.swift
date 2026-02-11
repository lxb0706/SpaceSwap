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
    @State private var isPulseAnimating = false
    
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
        NavigationStack {
            Group {
                if viewModel.scannedAssets.isEmpty && !viewModel.isScanning {
                    VStack(spacing: 28) {
                        Spacer()
                        VStack(spacing: 12) {
                            Text("Space Swap")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                            Text("Scan your photo library for large videos")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        
                        Button(action: {
                            viewModel.startScan()
                        }) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.blue, Color.cyan],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 150, height: 150)
                                    .shadow(color: Color.blue.opacity(0.45), radius: 20, x: 0, y: 12)
                                
                                Circle()
                                    .stroke(Color.blue.opacity(0.35), lineWidth: 2)
                                    .frame(width: 180, height: 180)
                                    .scaleEffect(isPulseAnimating ? 1.07 : 0.93)
                                    .opacity(isPulseAnimating ? 0.25 : 0.7)
                                    .animation(
                                        .easeInOut(duration: 1.4).repeatForever(autoreverses: true),
                                        value: isPulseAnimating
                                    )
                                
                                VStack(spacing: 6) {
                                    Image(systemName: "magnifyingglass")
                                        .font(.system(size: 28, weight: .semibold))
                                    Text("Start Scan")
                                        .font(.headline)
                                }
                                .foregroundColor(.white)
                            }
                        }
                        .buttonStyle(.plain)
                        .scaleEffect(isPulseAnimating ? 1.0 : 0.98)
                        .onAppear {
                            isPulseAnimating = true
                        }
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 24)
                } else {
                    VStack(spacing: 20) {
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
                            } else {
                                VStack(spacing: 8) {
                                    Text("\(viewModel.scannedAssets.count) large videos found")
                                        .font(.headline)
                                    Text("Potential savings: \(viewModel.potentialSavings.formattedBytes)")
                                        .font(.subheadline)
                                        .foregroundColor(.green)
                                }
                                .padding()
                            }
                        }
                        
                        if !viewModel.isScanning {
                            Button(action: {
                                viewModel.startScan()
                            }) {
                                HStack {
                                    Image(systemName: "magnifyingglass")
                                    Text("Scan Again")
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.blue)
                                .cornerRadius(12)
                            }
                            .padding(.horizontal)
                        }
                        
                        Picker("Sort by", selection: $sortOption) {
                            ForEach(SortOption.allCases, id: \.self) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                        .pickerStyle(.menu)
                        .padding(.horizontal)
                        
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(sortedAssets) { asset in
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
                                        .padding(.horizontal)
                                    }
                                }
                            }
                        }
                        .frame(maxHeight: 400)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    HomeView()
}
