//
//  CompressionView.swift
//  SpaceSwap
//
//  Created by 连晓彬 on 2026/2/9.
//

import SwiftUI
import AVKit
import Photos

struct CompressionView: View {
    let asset: PhotoAsset
    @StateObject private var viewModel: CompressionViewModel
    @StateObject private var playbackViewModel: CompressionPlaybackViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedQuality: CompressionQuality = .medium
    @State private var isFullscreenPlayerPresented = false
    @Namespace private var playerTransitionNamespace

    init(asset: PhotoAsset) {
        self.asset = asset
        _viewModel = StateObject(wrappedValue: CompressionViewModel())
        _playbackViewModel = StateObject(wrappedValue: CompressionPlaybackViewModel(asset: asset.phAsset))
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 24) {
                // Asset Preview
                VStack(spacing: 16) {
                    if !isFullscreenPlayerPresented {
                        previewPlayer
                    } else {
                        Color.clear
                            .frame(width: previewSize.width, height: previewSize.height)
                    }

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
                    .padding(.horizontal)
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
            if isFullscreenPlayerPresented {
                fullscreenPlayerOverlay
                    .zIndex(10)
            }
        }
        .navigationTitle("Compress Video")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar(isFullscreenPlayerPresented ? .hidden : .visible, for: .navigationBar)
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

    private var previewPlayer: some View {
        let size = previewSize
        return ZStack {
            playerSurface(cornerRadius: 16)
            fullscreenToggleButton(isFullscreen: false)
        }
        .frame(width: size.width, height: size.height)
        .matchedGeometryEffect(id: "playerContainer", in: playerTransitionNamespace)
    }

    private var fullscreenPlayerOverlay: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
                .transition(.opacity)

            ZStack {
                playerSurface(cornerRadius: 0)
                    .matchedGeometryEffect(id: "playerContainer", in: playerTransitionNamespace)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea()
                fullscreenToggleButton(isFullscreen: true)
            }
        }
        .transition(.opacity)
    }

    private func playerSurface(cornerRadius: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.black.opacity(0.92))

            if let message = playbackViewModel.loadErrorMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding()
            } else {
                VideoPlayer(player: playbackViewModel.player)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))

                if !playbackViewModel.isPlaying {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.white.opacity(0.9))
                }

                if !playbackViewModel.isReady {
                    ProgressView()
                        .tint(.white)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard playbackViewModel.loadErrorMessage == nil else { return }
            playbackViewModel.togglePlayback()
        }
    }

    private func fullscreenToggleButton(isFullscreen: Bool) -> some View {
        VStack {
            HStack {
                Spacer()
                if playbackViewModel.loadErrorMessage == nil {
                    Button {
                        withAnimation(.snappy(duration: 0.42, extraBounce: 0.02)) {
                            isFullscreenPlayerPresented = !isFullscreen
                        }
                    } label: {
                        Image(systemName: isFullscreen ? "xmark.circle.fill" : "viewfinder.circle.fill")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.95))
                            .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 12)
            .padding(.horizontal, 12)
            Spacer()
        }
        .zIndex(20)
    }

    private var previewSize: CGSize {
        let horizontalPadding: CGFloat = 32
        let maxEdge = max(UIScreen.main.bounds.width - horizontalPadding, 200)
        let width = max(CGFloat(asset.phAsset.pixelWidth), 1)
        let height = max(CGFloat(asset.phAsset.pixelHeight), 1)
        let aspect = width / height

        if aspect >= 1 {
            return CGSize(width: maxEdge, height: maxEdge / aspect)
        }
        return CGSize(width: maxEdge * aspect, height: maxEdge)
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
