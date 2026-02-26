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
    @StateObject private var queueManager: CompressionQueueManager
    @StateObject private var playbackViewModel: CompressionPlaybackViewModel
    @StateObject private var locationViewModel: CompressionLocationViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedQuality: CompressionQuality = .medium
    @State private var isFullscreenPlayerPresented = false
    @State private var isMetadataInfoPresented = false
    @State private var isQueueSheetPresented = false
    @State private var queueAlertMessage: String?
    @State private var didLoadCompressedPreview = false
    @Namespace private var playerTransitionNamespace

    init(asset: PhotoAsset) {
        self.asset = asset
        _queueManager = StateObject(wrappedValue: CompressionQueueManager.shared)
        _playbackViewModel = StateObject(wrappedValue: CompressionPlaybackViewModel(asset: asset.phAsset))
        _locationViewModel = StateObject(wrappedValue: CompressionLocationViewModel(location: asset.phAsset.location))
    }
    
    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 16) {
                    if !isFullscreenPlayerPresented {
                        previewPlayer
                    } else {
                        Color.clear
                            .frame(width: previewSize.width, height: previewSize.height)
                    }

                    HStack(spacing: 6) {
                        Image(systemName: isCompressedPreview ? "checkmark.seal.fill" : "circle.fill")
                            .font(.caption)
                        Text(isCompressedPreview ? "Showing Compressed Video" : "Showing Original Video")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(isCompressedPreview ? .green : .secondary)

                    videoDetailsCard
                    compressionSettingsCard

                    if let entry = currentQueueEntry {
                        compressionStatusBanner(entry: entry)
                    }

                    compressionActionSection

                    if let result = currentQueueEntry?.record {
                        compressionResultCard(result: result)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .padding(.bottom, 20)
            }
            .scrollIndicators(.visible)
            if isFullscreenPlayerPresented {
                fullscreenPlayerOverlay
                    .zIndex(10)
            }
        }
        .navigationTitle("Compress Video")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar(isFullscreenPlayerPresented ? .hidden : .visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if !isFullscreenPlayerPresented {
                    Button {
                        isQueueSheetPresented = true
                    } label: {
                        Image(systemName: "list.bullet.rectangle")
                    }
                }
            }
        }
        .alert("Queue Message", isPresented: Binding(
            get: { queueAlertMessage != nil },
            set: { newValue in
                if !newValue { queueAlertMessage = nil }
            }
        ), actions: {
            Button("OK", role: .cancel) { queueAlertMessage = nil }
        }, message: {
            Text(queueAlertMessage ?? "")
        })
        .sheet(isPresented: $isMetadataInfoPresented) {
            metadataInfoSheet
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isQueueSheetPresented) {
            CompressionQueueSheetView(queueManager: queueManager)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .task {
            await locationViewModel.resolveIfNeeded()
            await loadCompressedPreviewIfNeeded()
        }
        .onChange(of: currentQueueEntry?.status) { _, _ in
            Task {
                await loadCompressedPreviewIfNeeded()
            }
        }
    }

    private var currentQueueEntry: CompressionQueueEntry? {
        queueManager.entry(for: asset.id)
    }

    private var isCompressedPreview: Bool {
        currentQueueEntry?.status == .success
    }

    private var videoDetailsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text("Video Details")
                    .font(.headline)
                Spacer()
                Button {
                    isMetadataInfoPresented = true
                } label: {
                    Label("More Details", systemImage: "info.circle")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.plain)
            }

            detailRow(title: "Name", value: asset.filename)
            detailRow(title: "Size", value: asset.fileSize.formattedBytes)
            detailRow(title: "Duration", value: asset.duration.formattedDuration)
            detailRow(title: "Resolution", value: "\(asset.phAsset.pixelWidth) × \(asset.phAsset.pixelHeight)")
        }
        .padding(12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private var compressionSettingsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Compression Quality")
                .font(.headline)

            Picker("Quality", selection: $selectedQuality) {
                ForEach(CompressionQuality.allCases, id: \.self) { quality in
                    Text(quality.rawValue).tag(quality)
                }
            }
            .pickerStyle(.segmented)
            .disabled(currentQueueEntry != nil)

            VStack(alignment: .leading, spacing: 4) {
                Text("Estimated Results")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Text("Original: \(asset.fileSize.formattedBytes)")
                    Spacer()
                    Text("Estimated: ~\(estimatedCompressedSize(asset.fileSize, quality: selectedQuality).formattedBytes)")
                }
                .font(.caption)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private func compressionResultCard(result: CompressionRecord) -> some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Compression Complete")
                    .font(.headline)
                Spacer()
            }

            detailRow(title: "Original", value: result.originalSize.formattedBytes)
            detailRow(title: "Compressed", value: result.compressedSize.formattedBytes)
            detailRow(
                title: "Saved",
                value: (result.originalSize - result.compressedSize).formattedBytes
            )

            Button("Done") {
                dismiss()
            }
            .font(.headline)
            .foregroundColor(.white)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(Color.green)
            .cornerRadius(10)
        }
        .padding(12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private var compressionActionSection: some View {
        if let entry = currentQueueEntry, entry.status == .success {
            return AnyView(EmptyView())
        }

        return AnyView(
        VStack(spacing: 12) {
            if let entry = currentQueueEntry, entry.status == .queued || entry.status == .running {
                ProgressView(value: entry.progress)
                    .progressViewStyle(.linear)
                Text(entry.status == .queued ? "Waiting in queue..." : "Compressing...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if entry.status == .queued {
                    Text("Queue: \(queueManager.waitingCount) waiting, \(queueManager.runningCount) running")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Text("\(Int(entry.progress * 100))%")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Button(action: handleCompressionAction) {
                HStack {
                    Image(systemName: actionButtonIconName)
                    Text(actionButtonTitle)
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(actionButtonColor)
                .cornerRadius(12)
            }
            .disabled(actionButtonDisabled)
        }
        )
    }

    private var actionButtonTitle: String {
        guard let entry = currentQueueEntry else { return "Start Compression" }
        switch entry.status {
        case .queued:
            return "Cancel (Waiting)"
        case .running:
            return "Cancel (Compressing)"
        case .success:
            return "Already Compressed"
        case .failed:
            return "Compression Failed (Session Locked)"
        case .cancelled:
            return "Cancelled (Session Locked)"
        }
    }

    private var actionButtonIconName: String {
        guard let entry = currentQueueEntry else { return "arrow.triangle.2.circlepath" }
        switch entry.status {
        case .queued, .running:
            return "xmark"
        case .success:
            return "checkmark.circle"
        case .failed:
            return "exclamationmark.triangle"
        case .cancelled:
            return "slash.circle"
        }
    }

    private var actionButtonColor: Color {
        guard let entry = currentQueueEntry else { return .blue }
        switch entry.status {
        case .queued:
            return .orange
        case .running:
            return .red
        case .success:
            return .green
        case .failed, .cancelled:
            return .gray
        }
    }

    private var actionButtonDisabled: Bool {
        guard let entry = currentQueueEntry else { return false }
        switch entry.status {
        case .queued, .running:
            return false
        case .success, .failed, .cancelled:
            return true
        }
    }

    private func handleCompressionAction() {
        if let entry = currentQueueEntry {
            switch entry.status {
            case .queued, .running:
                queueManager.cancel(assetID: asset.id)
            case .success, .failed, .cancelled:
                queueAlertMessage = "This video has already been processed in this app session."
            }
            return
        }

        let accepted = queueManager.enqueue(asset: asset, quality: selectedQuality)
        if !accepted {
            queueAlertMessage = "This video is already in the queue for this app session."
        }
    }

    private func compressionStatusBanner(entry: CompressionQueueEntry) -> some View {
        HStack(spacing: 8) {
            Image(systemName: statusBannerIcon(entry.status))
            Text(statusBannerText(entry.status))
                .font(.subheadline.weight(.semibold))
            Spacer()
        }
        .padding(10)
        .background(statusBannerColor(entry.status).opacity(0.14), in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(statusBannerColor(entry.status).opacity(0.25), lineWidth: 1)
        )
    }

    private func statusBannerIcon(_ status: CompressionQueueStatus) -> String {
        switch status {
        case .queued:
            return "clock.fill"
        case .running:
            return "arrow.triangle.2.circlepath.circle.fill"
        case .success:
            return "checkmark.seal.fill"
        case .failed:
            return "xmark.octagon.fill"
        case .cancelled:
            return "minus.circle.fill"
        }
    }

    private func statusBannerText(_ status: CompressionQueueStatus) -> String {
        switch status {
        case .queued:
            return "Queued for compression"
        case .running:
            return "Compressing now"
        case .success:
            return "Already compressed in this session"
        case .failed:
            return "Compression failed in this session"
        case .cancelled:
            return "Compression cancelled in this session"
        }
    }

    private func statusBannerColor(_ status: CompressionQueueStatus) -> Color {
        switch status {
        case .queued:
            return .orange
        case .running:
            return .blue
        case .success:
            return .green
        case .failed:
            return .red
        case .cancelled:
            return .gray
        }
    }

    private func loadCompressedPreviewIfNeeded() async {
        guard !didLoadCompressedPreview else { return }
        guard let entry = currentQueueEntry, entry.status == .success else { return }
        guard let compressedID = entry.record?.compressedAssetID else { return }

        let result = PHAsset.fetchAssets(withLocalIdentifiers: [compressedID], options: nil)
        guard let compressedAsset = result.firstObject else { return }

        didLoadCompressedPreview = true
        playbackViewModel.loadPlayerItem(for: compressedAsset)
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
