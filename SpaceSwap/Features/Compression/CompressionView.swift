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

    init(asset: PhotoAsset) {
        self.asset = asset
        _viewModel = StateObject(wrappedValue: CompressionViewModel())
        _playbackViewModel = StateObject(wrappedValue: CompressionPlaybackViewModel(asset: asset.phAsset))
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // Asset Preview
            VStack(spacing: 16) {
                previewPlayer
                
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
        .navigationTitle("Compress Video")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .fullScreenCover(isPresented: $isFullscreenPlayerPresented) {
            FullscreenPlayerView(
                playbackViewModel: playbackViewModel,
                dismissFullscreen: { isFullscreenPlayerPresented = false }
            )
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

    private var previewPlayer: some View {
        let size = previewSize
        return ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.92))

            if let message = playbackViewModel.loadErrorMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding()
            } else {
                VideoPlayer(player: playbackViewModel.player)
                    .onTapGesture {
                        playbackViewModel.togglePlayback()
                    }
                    .overlay(alignment: .center) {
                        if !playbackViewModel.isPlaying {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(.white.opacity(0.9))
                        }
                    }
                    .overlay(alignment: .bottomTrailing) {
                        Button {
                            isFullscreenPlayerPresented = true
                        } label: {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(10)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        .padding(12)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                if !playbackViewModel.isReady {
                    ProgressView()
                        .tint(.white)
                }
            }
        }
        .frame(width: size.width, height: size.height)
        .overlay(alignment: .bottom) {
            PlaybackControlsView(playbackViewModel: playbackViewModel, showsFullscreenButton: false, toggleFullscreen: {})
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
        }
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

private struct PlaybackControlsView: View {
    @ObservedObject var playbackViewModel: CompressionPlaybackViewModel
    let showsFullscreenButton: Bool
    let toggleFullscreen: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Text(playbackViewModel.formattedTime(playbackViewModel.currentTime))
                    .font(.caption2.monospacedDigit())
                    .foregroundColor(.white)

                Slider(
                    value: Binding(
                        get: { playbackViewModel.currentTime },
                        set: { playbackViewModel.updateScrubbingTime($0) }
                    ),
                    in: 0...max(playbackViewModel.duration, 0.1),
                    onEditingChanged: { editing in
                        if editing {
                            playbackViewModel.beginScrubbing()
                        } else {
                            playbackViewModel.endScrubbing()
                        }
                    }
                )
                .tint(.white)
                .disabled(!playbackViewModel.isReady)

                Text(playbackViewModel.formattedTime(playbackViewModel.duration))
                    .font(.caption2.monospacedDigit())
                    .foregroundColor(.white)
            }

            HStack(spacing: 20) {
                Button {
                    playbackViewModel.togglePlayback()
                } label: {
                    Image(systemName: playbackViewModel.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 34, height: 34)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .disabled(!playbackViewModel.isReady)

                if showsFullscreenButton {
                    Button {
                        toggleFullscreen()
                    } label: {
                        Image(systemName: "arrow.down.right.and.arrow.up.left")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 34, height: 34)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                }
            }
        }
        .padding(10)
        .background(Color.black.opacity(0.42), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct FullscreenPlayerView: View {
    @ObservedObject var playbackViewModel: CompressionPlaybackViewModel
    let dismissFullscreen: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()

            VStack {
                Spacer()
                VideoPlayer(player: playbackViewModel.player)
                    .aspectRatio(contentMode: .fit)
                    .onTapGesture {
                        playbackViewModel.togglePlayback()
                    }
                Spacer()
            }
            .ignoresSafeArea()

            Button {
                dismissFullscreen()
            } label: {
                Image(systemName: "arrow.down.right.and.arrow.up.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 42, height: 42)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .padding(.top, 14)
            .padding(.leading, 14)

            VStack {
                Spacer()
                PlaybackControlsView(
                    playbackViewModel: playbackViewModel,
                    showsFullscreenButton: false,
                    toggleFullscreen: {}
                )
                .padding(.horizontal, 14)
                .padding(.bottom, 18)
            }
        }
        .statusBar(hidden: true)
    }
}
