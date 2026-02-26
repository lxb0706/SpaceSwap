//
//  CompressionView.swift
//  SpaceSwap
//
//  Created by 连晓彬 on 2026/2/9.
//

import SwiftUI
import AVKit
import Photos
import MapKit
import CoreLocation
import Combine

struct CompressionView: View {
    let asset: PhotoAsset
    @StateObject private var viewModel: CompressionViewModel
    @StateObject private var playbackViewModel: CompressionPlaybackViewModel
    @StateObject private var locationViewModel: CompressionLocationViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedQuality: CompressionQuality = .medium
    @State private var isFullscreenPlayerPresented = false
    @State private var isMetadataInfoPresented = false
    @Namespace private var playerTransitionNamespace

    init(asset: PhotoAsset) {
        self.asset = asset
        _viewModel = StateObject(wrappedValue: CompressionViewModel())
        _playbackViewModel = StateObject(wrappedValue: CompressionPlaybackViewModel(asset: asset.phAsset))
        _locationViewModel = StateObject(wrappedValue: CompressionLocationViewModel(location: asset.phAsset.location))
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
                        HStack(spacing: 6) {
                            Text("Video Details")
                                .font(.headline)
                            Button {
                                isMetadataInfoPresented = true
                            } label: {
                                Image(systemName: "info.circle")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }

                        VStack(spacing: 6) {
                            detailRow(title: "Name", value: asset.filename)
                            detailRow(title: "Original Size", value: asset.fileSize.formattedBytes)
                            detailRow(title: "Duration", value: asset.duration.formattedDuration)
                            detailRow(title: "Resolution", value: "\(asset.phAsset.pixelWidth) × \(asset.phAsset.pixelHeight)")
                            detailRow(title: "Created", value: formattedDate(asset.creationDate) ?? "Unknown")
                            detailRow(title: "Location", value: locationViewModel.primaryLocationText)
                            detailRow(title: "Storage", value: asset.isCloudAsset ? "iCloud (download on demand)" : "On Device")
                        }
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
        .sheet(isPresented: $isMetadataInfoPresented) {
            metadataInfoSheet
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .task {
            await locationViewModel.resolveIfNeeded()
        }
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

    private func detailRow(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 10)
            Text(value)
                .font(.caption)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
        }
    }

    private func formattedDate(_ date: Date?) -> String? {
        guard let date else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private var metadataInfoSheet: some View {
        let technical = technicalInfo
        return NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Metadata Retention")
                            .font(.headline)
                        Text("Compression mainly changes file size and output quality. Creation date, location and most library metadata are preserved whenever Photos export supports it.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Basic")
                            .font(.headline)
                        detailRow(title: "Name", value: asset.filename)
                        detailRow(title: "Original Size", value: asset.fileSize.formattedBytes)
                        detailRow(title: "Duration", value: formattedDurationDetailed(asset.duration))
                        detailRow(title: "Resolution", value: readableResolutionText(width: asset.phAsset.pixelWidth, height: asset.phAsset.pixelHeight))
                        detailRow(title: "Orientation", value: orientationText(width: asset.phAsset.pixelWidth, height: asset.phAsset.pixelHeight))
                        detailRow(title: "Created", value: formattedDate(asset.creationDate) ?? "Unknown")
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Location")
                            .font(.headline)
                        detailRow(title: "Place", value: locationViewModel.primaryLocationText)
                        if let locationDetail = locationViewModel.secondaryLocationText {
                            detailRow(title: "Address", value: locationDetail)
                        }
                        if let location = asset.phAsset.location {
                            locationMapView(location: location)
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Technical")
                            .font(.headline)
                        detailRow(title: "Codec", value: technical.codec)
                        detailRow(title: "Frame Rate", value: technical.frameRate)
                        detailRow(title: "Estimated Bitrate", value: technical.bitrate)
                        detailRow(title: "Storage", value: asset.isCloudAsset ? "iCloud (download on demand)" : "On Device")
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Expected To Keep")
                            .font(.headline)
                        metadataBullet("Creation date and timeline placement")
                        metadataBullet("Location metadata and map placement")
                        metadataBullet("Duration and dimensions relationship")
                        metadataBullet("Library organization behavior")
                    }
                }
                .padding()
            }
            .navigationTitle("More Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        isMetadataInfoPresented = false
                    }
                }
            }
        }
    }

    private func metadataBullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
                .padding(.top, 2)
            Text(text)
                .font(.subheadline)
        }
    }

    private func locationMapView(location: CLLocation) -> some View {
        let region = MKCoordinateRegion(
            center: location.coordinate,
            latitudinalMeters: 1200,
            longitudinalMeters: 1200
        )
        return Map(initialPosition: .region(region)) {
            Marker("Capture Location", coordinate: location.coordinate)
        }
        .frame(height: 180)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var technicalInfo: (codec: String, frameRate: String, bitrate: String) {
        (
            codec: "Source dependent (preserved when possible)",
            frameRate: "Source dependent (preserved when possible)",
            bitrate: readableBitrate(asset.fileSize, duration: asset.duration)
        )
    }

    private func readableBitrate(_ size: Int64, duration: TimeInterval) -> String {
        guard duration > 0 else { return "Unknown" }
        let bps = (Double(size) * 8.0) / duration
        let mbps = bps / 1_000_000
        return String(format: "%.2f Mbps", mbps)
    }

    private func formattedDurationDetailed(_ duration: TimeInterval) -> String {
        let totalSeconds = Int(duration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d h %02d m %02d s", hours, minutes, seconds)
        }
        return String(format: "%d m %02d s", minutes, seconds)
    }

    private func readableResolutionText(width: Int, height: Int) -> String {
        let gcdValue = gcd(width, height)
        let ratioW = width / max(gcdValue, 1)
        let ratioH = height / max(gcdValue, 1)
        return "\(width) × \(height) (\(ratioW):\(ratioH))"
    }

    private func orientationText(width: Int, height: Int) -> String {
        if width == height { return "Square" }
        return width > height ? "Landscape" : "Portrait"
    }

    private func gcd(_ a: Int, _ b: Int) -> Int {
        var x = abs(a)
        var y = abs(b)
        while y != 0 {
            let t = x % y
            x = y
            y = t
        }
        return x
    }
}

@MainActor
final class CompressionLocationViewModel: ObservableObject {
    @Published private(set) var primaryLocationText: String = "Resolving..."
    @Published private(set) var secondaryLocationText: String?

    private let location: CLLocation?
    private var hasResolved = false

    init(location: CLLocation?) {
        self.location = location
        if location == nil {
            self.primaryLocationText = "Unavailable"
        }
    }

    func resolveIfNeeded() async {
        guard !hasResolved else { return }
        hasResolved = true

        guard let location else {
            primaryLocationText = "Unavailable"
            secondaryLocationText = nil
            return
        }

        let geocoder = CLGeocoder()
        do {
            let placemarks = try await reverseGeocode(geocoder: geocoder, location: location)
            if let placemark = placemarks.first {
                let place = [placemark.name, placemark.locality, placemark.administrativeArea, placemark.country]
                    .compactMap { $0 }
                    .filter { !$0.isEmpty }
                primaryLocationText = place.first ?? "Known place"

                let detail = [
                    placemark.subLocality,
                    placemark.thoroughfare,
                    placemark.subThoroughfare,
                    placemark.locality,
                    placemark.administrativeArea,
                    placemark.postalCode,
                    placemark.country
                ]
                .compactMap { $0 }
                .filter { !$0.isEmpty }
                .joined(separator: ", ")
                secondaryLocationText = detail.isEmpty ? nil : detail
            } else {
                primaryLocationText = "Location detected"
                secondaryLocationText = nil
            }
        } catch {
            primaryLocationText = "Location detected"
            secondaryLocationText = nil
        }
    }

    private func reverseGeocode(geocoder: CLGeocoder, location: CLLocation) async throws -> [CLPlacemark] {
        try await withCheckedThrowingContinuation { continuation in
            geocoder.reverseGeocodeLocation(location) { placemarks, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: placemarks ?? [])
                }
            }
        }
    }
}
