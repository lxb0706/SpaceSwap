//
//  HomeView.swift
//  SpaceSwap
//
//  Created by 连晓彬 on 2026/2/9.
//

import SwiftUI
import Photos
import CoreLocation
import MapKit
import UIKit

public struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @StateObject private var queueManager = CompressionQueueManager.shared
    @State private var sortOption: SortOption = .dateNewest
    @State private var pendingScanStart = false
    @State private var canShowResults = false
    @State private var showDockingControl = true
    @State private var showCompletionState = false
    @State private var isDismissingScanControl = false
    @State private var showToolbarRescanButton = false
    @State private var shouldFlipProgress = false
    @State private var ripplePhase = false
    @State private var isNavBarCollapsed = false
    @State private var resultsTopBaseline: CGFloat?
    @State private var showStopScanAlert = false
    @State private var shouldSkipFinishTransition = false
    @State private var visibleAssetIDs: Set<String> = []
    @State private var selectedAssetForCompression: PhotoAsset?
    @State private var isQueueSheetPresented = false
    @State private var revealTask: Task<Void, Never>?
    @State private var transitionTask: Task<Void, Never>?

    enum SortOption: String, CaseIterable {
        case sizeDescending = "Size (Large First)"
        case sizeAscending = "Size (Small First)"
        case dateNewest = "Date (Newest)"
        case dateOldest = "Date (Oldest)"
    }

    private var sortedAssets: [PhotoAsset] {
        switch sortOption {
        case .sizeDescending:
            return viewModel.scannedAssets.sorted { $0.fileSize > $1.fileSize }
        case .sizeAscending:
            return viewModel.scannedAssets.sorted { $0.fileSize < $1.fileSize }
        case .dateNewest:
            return viewModel.scannedAssets.sorted {
                ($0.creationDate ?? .distantPast) > ($1.creationDate ?? .distantPast)
            }
        case .dateOldest:
            return viewModel.scannedAssets.sorted {
                ($0.creationDate ?? .distantPast) < ($1.creationDate ?? .distantPast)
            }
        }
    }

    private var scanProgressPercent: Int {
        if isScanningVisualActive {
            return max(0, min(100, Int(viewModel.scanProgress * 100)))
        }
        return max(0, min(100, Int(viewModel.scanProgress * 100)))
    }

    private var isScanningVisualActive: Bool {
        viewModel.isScanning || pendingScanStart
    }

    private var scanEnergy: Double {
        guard isScanningVisualActive else { return 0.0 }
        let progress = min(max(viewModel.scanProgress, 0.0), 1.0)
        return 0.45 + progress * 0.55
    }

    private func startScanEffects() {
        ripplePhase = false
        withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
            ripplePhase = true
        }
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                content

                if showDockingControl {
                    scanControl
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        .scaleEffect(isDismissingScanControl ? 0.78 : 1.0)
                        .opacity(isDismissingScanControl ? 0.0 : 1.0)
                        .animation(.easeInOut(duration: 0.35), value: isDismissingScanControl)
                        .animation(.easeInOut(duration: 0.25), value: viewModel.scanProgress)
                        .animation(.easeInOut(duration: 0.2), value: showCompletionState)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(
                (canShowResults && !viewModel.scannedAssets.isEmpty && isNavBarCollapsed) ? .hidden : .visible,
                for: .navigationBar
            )
            .navigationBarHidden(canShowResults && !viewModel.scannedAssets.isEmpty && isNavBarCollapsed)
            .toolbar {
                if showToolbarRescanButton && !viewModel.isScanning && !viewModel.scannedAssets.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        toolbarIconButton(symbol: "arrow.clockwise", accessibilityLabel: "Rescan") {
                            triggerScan()
                        }
                    }
                }

                if !viewModel.isScanning {
                    ToolbarItem(placement: .topBarTrailing) {
                        toolbarIconButton(symbol: "slider.horizontal.3", accessibilityLabel: "Settings") {
                            // Settings entry point placeholder.
                        }
                    }
                }
            }
            .onChange(of: viewModel.isScanning) { oldValue, newValue in
                if !oldValue && newValue {
                    pendingScanStart = false
                    canShowResults = false
                    isNavBarCollapsed = false
                    transitionTask?.cancel()
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                        showDockingControl = true
                        showCompletionState = false
                        isDismissingScanControl = false
                    }
                    showToolbarRescanButton = false
                }

                if oldValue && !newValue {
                    pendingScanStart = false
                    if shouldSkipFinishTransition {
                        shouldSkipFinishTransition = false
                        return
                    }
                    handleScanFinished()
                }
            }
            .onChange(of: scanProgressPercent) { _, _ in
                guard isScanningVisualActive else { return }
                shouldFlipProgress.toggle()
            }
            .onChange(of: viewModel.scannedAssets) { _, newValue in
                if canShowResults {
                    startStaggerReveal(for: sortedAssets.map(\.id))
                }
            }
            .onChange(of: canShowResults) { _, newValue in
                if !newValue {
                    resultsTopBaseline = nil
                    isNavBarCollapsed = false
                }
            }
            .onChange(of: isScanningVisualActive) { _, isActive in
                if isActive {
                    startScanEffects()
                } else {
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        ripplePhase = false
                    }
                }
            }
            .navigationDestination(item: $selectedAssetForCompression) { asset in
                CompressionView(asset: asset)
            }
            .sheet(isPresented: $isQueueSheetPresented) {
                CompressionQueueSheetView(queueManager: queueManager)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .alert("Stop scanning now?", isPresented: $showStopScanAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Confirm Stop", role: .destructive) {
                    stopScanAndReset()
                }
            } message: {
                Text("Current scan progress will be discarded and found results will be cleared.")
            }
        }
    }

    private var content: some View {
        VStack(spacing: 16) {
            if viewModel.scannedAssets.isEmpty {
                VStack(spacing: 10) {
                    Text("Space Swap")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text(isScanningVisualActive ? "Scanning your photo library..." : "Scan your photo library for large videos")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    if isScanningVisualActive {
                        HStack(spacing: 4) {
                            Text("Matched")
                            Text("\(viewModel.scanningMatchedCount)")
                                .fontWeight(.bold)
                                .monospacedDigit()
                                .frame(minWidth: 56, alignment: .trailing)
                                .contentTransition(.numericText())
                            Text("videos")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                        Text("Progress updates as assets are analyzed")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 72)
                Spacer()
            } else {
                if canShowResults {
                    ScrollView {
                        VStack(spacing: 12) {
                            Color.clear
                                .frame(height: 0)
                                .background(
                                    GeometryReader { proxy in
                                        Color.clear.preference(
                                            key: ScrollOffsetPreferenceKey.self,
                                            value: proxy.frame(in: .named("resultsScroll")).minY
                                        )
                                    }
                                )

                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(viewModel.scannedAssets.count) large videos")
                                        .font(.headline)
                                    Text("Potential savings: \(viewModel.potentialSavings.formattedBytes)")
                                        .font(.subheadline)
                                        .foregroundColor(.green)
                                }
                                Spacer()
                                Picker("Sort by", selection: $sortOption) {
                                    ForEach(SortOption.allCases, id: \.self) { option in
                                        Text(option.rawValue).tag(option)
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                            .padding(.top, 8)

                            LazyVStack(spacing: 12) {
                                ForEach(sortedAssets.filter { visibleAssetIDs.contains($0.id) }) { asset in
                                    Button {
                                        handleAssetTap(asset)
                                    } label: {
                                        let compressedCopyRecord = viewModel.compressedCopyRecordsByAssetID[asset.id]
                                        let displayName: String = {
                                            guard let compressedCopyRecord else { return asset.filename }
                                            guard !compressedCopyRecord.originalFilename.isEmpty else { return asset.filename }
                                            return String.spaceswapCompressedCopyDisplayName(
                                                originalFilename: compressedCopyRecord.originalFilename,
                                                sequence: 1
                                            )
                                        }()

                                        AssetRowView(
                                            asset: asset,
                                            displayName: displayName,
                                            isCompressedCopy: compressedCopyRecord != nil,
                                            compressionEntry: queueManager.entry(for: asset.id)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .transition(.move(edge: .bottom).combined(with: .opacity))
                                }
                            }
                            .animation(.easeOut(duration: 0.28), value: visibleAssetIDs)
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 100)
                    }
                    .coordinateSpace(name: "resultsScroll")
                    .onPreferenceChange(ScrollOffsetPreferenceKey.self) { currentOffset in
                        if resultsTopBaseline == nil {
                            resultsTopBaseline = currentOffset
                            return
                        }
                        guard let baseline = resultsTopBaseline else { return }
                        let delta = currentOffset - baseline
                        // UIKit-like behavior: scrolling up (negative delta) hides nav bar.
                        let shouldHide = delta < -8
                        // Pulling down to top region shows nav bar again.
                        let shouldShow = delta > -1

                        if shouldHide, !isNavBarCollapsed {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isNavBarCollapsed = true
                            }
                        } else if shouldShow, isNavBarCollapsed {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isNavBarCollapsed = false
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea(.container, edges: [.bottom])
                } else {
                    VStack(spacing: 8) {
                        ProgressView()
                        Text("Finalizing scan...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var scanControl: some View {
        Button {
            if isScanningVisualActive {
                showStopScanAlert = true
            } else {
                triggerScan()
            }
        } label: {
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
                    .stroke(Color.white.opacity(0.15), lineWidth: 9)
                    .frame(width: 178, height: 178)

                Circle()
                    .trim(from: 0.0, to: showCompletionState ? 1.0 : max(viewModel.scanProgress, 0.0))
                    .stroke(
                        Color.cyan,
                        style: StrokeStyle(lineWidth: 9, lineCap: .round, lineJoin: .round)
                    )
                    .frame(width: 178, height: 178)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: Color.cyan.opacity(0.55), radius: 10, x: 0, y: 0)
                    .opacity(isScanningVisualActive || showCompletionState ? 1.0 : 0.35)

                Circle()
                    .stroke(Color.cyan.opacity(0.62), lineWidth: 3)
                    .frame(width: 182, height: 182)
                    .scaleEffect(ripplePhase ? 1.1 : 0.95)
                    .opacity(isScanningVisualActive ? 0.28 + scanEnergy * 0.2 : 0.0)
                    .blur(radius: ripplePhase ? 0.4 : 0)

                VStack(spacing: 6) {
                    if showCompletionState {
                        Image(systemName: "checkmark")
                            .font(.system(size: 30, weight: .bold))
                        Text("Done")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                    } else if isScanningVisualActive {
                        Text("\(scanProgressPercent)%")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                            .rotation3DEffect(
                                .degrees(shouldFlipProgress ? -12 : 0),
                                axis: (x: 1, y: 0, z: 0),
                                perspective: 0.7
                            )
                            .animation(.spring(response: 0.28, dampingFraction: 0.62), value: shouldFlipProgress)
                    } else {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 28, weight: .semibold))
                        Text("Start Scan")
                            .font(.headline)
                    }
                }
                .foregroundColor(.white)

            }
        }
        .buttonStyle(.plain)
        .scaleEffect(viewModel.isScanning ? 1.02 : 1.0)
    }

    private func triggerScan() {
        transitionTask?.cancel()
        revealTask?.cancel()
        showToolbarRescanButton = false
        showDockingControl = true
        canShowResults = false
        isNavBarCollapsed = false
        resultsTopBaseline = nil
        pendingScanStart = true
        startScanEffects()
        showCompletionState = false
        isDismissingScanControl = false
        visibleAssetIDs = []
        Task { @MainActor in
            // Let the view render 1% state first, then start scanning.
            await Task.yield()
            guard pendingScanStart else { return }
            viewModel.startScan()
        }
    }

    private func handleScanFinished() {
        guard !viewModel.scannedAssets.isEmpty else {
            withAnimation(.easeInOut(duration: 0.25)) {
                showCompletionState = false
                showDockingControl = true
                isDismissingScanControl = false
            }
            showToolbarRescanButton = false
            return
        }

        transitionTask?.cancel()
        transitionTask = Task { @MainActor in
            withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) {
                showCompletionState = true
            }
            let notification = UINotificationFeedbackGenerator()
            notification.notificationOccurred(.success)

            // Keep "Done" on screen for a full beat before dismissing.
            try? await Task.sleep(nanoseconds: 1_200_000_000)

            withAnimation(.easeOut(duration: 0.45)) {
                isDismissingScanControl = true
            }
            try? await Task.sleep(nanoseconds: 500_000_000)

            showDockingControl = false
            showCompletionState = false
            isDismissingScanControl = false
            canShowResults = true
            isNavBarCollapsed = false
            resultsTopBaseline = nil
            showToolbarRescanButton = true
            startStaggerReveal(for: sortedAssets.map(\.id))
        }
    }

    private func stopScanAndReset() {
        shouldSkipFinishTransition = true
        transitionTask?.cancel()
        revealTask?.cancel()
        viewModel.cancelScan()
        viewModel.clearResults()

        withAnimation(.easeInOut(duration: 0.2)) {
            showDockingControl = true
            showCompletionState = false
            isDismissingScanControl = false
            canShowResults = false
            showToolbarRescanButton = false
            isNavBarCollapsed = false
        }

        resultsTopBaseline = nil
        pendingScanStart = false
        visibleAssetIDs = []
    }

    private func startStaggerReveal(for ids: [String]) {
        revealTask?.cancel()
        visibleAssetIDs = []

        guard !ids.isEmpty else { return }

        revealTask = Task { @MainActor in
            for id in ids {
                if Task.isCancelled { return }
                _ = withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    visibleAssetIDs.insert(id)
                }
                try? await Task.sleep(nanoseconds: 35_000_000)
            }
        }
    }

    private func toolbarIconButton(
        symbol: String,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.primary)
                .frame(width: 30, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    private func handleAssetTap(_ asset: PhotoAsset) {
        if let entry = queueManager.entry(for: asset.id), entry.status == .queued || entry.status == .running {
            isQueueSheetPresented = true
        } else {
            selectedAssetForCompression = asset
        }
    }
}

private struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct AssetRowView: View {
    let asset: PhotoAsset
    let displayName: String
    let isCompressedCopy: Bool
    let compressionEntry: CompressionQueueEntry?
    @State private var resolvedLocationName: String?
    @State private var didAnimateIn = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AssetThumbnailView(asset: asset)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(displayName)
                        .font(.headline)
                        .lineLimit(1)

                    if isCompressedCopy {
                        Text("Compressed Copy")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.18), in: Capsule())
                            .foregroundColor(.green)
                    }
                }

                HStack(spacing: 12) {
                    Label {
                        Text(asset.fileSize.formattedBytes)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    } icon: {
                        Image(systemName: "internaldrive")
                    }
                    Label(asset.duration.formattedDuration, systemImage: "clock")
                }
                .font(.caption)
                .foregroundColor(.secondary)

                Label(
                    asset.creationDate?.formatted(date: .abbreviated, time: .shortened) ?? "Unknown Date",
                    systemImage: "calendar"
                )
                .font(.caption)
                .foregroundColor(.secondary)

                if let displayLocation = displayLocationText {
                    Label(displayLocation, systemImage: "mappin.and.ellipse")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                if let compressionEntry {
                    compressionBadge(compressionEntry)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 10) {
                if asset.isCloudAsset {
                    Image(systemName: "icloud")
                        .foregroundColor(.blue)
                }
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
        .opacity(didAnimateIn ? 1.0 : 0.0)
        .offset(y: didAnimateIn ? 0 : 14)
        .scaleEffect(didAnimateIn ? 1.0 : 0.985)
        .onAppear {
            withAnimation(.easeOut(duration: 0.26)) {
                didAnimateIn = true
            }
        }
        .onDisappear {
            didAnimateIn = false
        }
        .task(id: asset.id) {
            await resolveLocationNameIfNeeded()
        }
    }

    private var displayLocationText: String? {
        if let resolvedLocationName {
            return resolvedLocationName
        }
        return asset.locationText
    }

    private func resolveLocationNameIfNeeded() async {
        guard let latitude = asset.latitude, let longitude = asset.longitude else {
            return
        }

        let locationName = await LocationNameCache.shared.resolveLocationName(
            latitude: latitude,
            longitude: longitude
        )

        guard let locationName else {
            return
        }

        await MainActor.run {
            resolvedLocationName = locationName
        }
    }

    private func compressionBadge(_ entry: CompressionQueueEntry) -> some View {
        let text: String
        let color: Color
        switch entry.status {
        case .queued:
            text = "Queued"
            color = .orange
        case .running:
            text = "Compressing"
            color = .blue
        case .success:
            text = "Compressed"
            color = .green
        case .failed:
            text = "Failed"
            color = .red
        case .cancelled:
            text = "Cancelled"
            color = .gray
        }

        return HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(text)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.12), in: Capsule())
    }
}

private struct AssetThumbnailView: View {
    let asset: PhotoAsset
    @State private var thumbnail: UIImage?
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.gray.opacity(0.18))

            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "video.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 96, height: 96)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .task(id: asset.id) {
            let targetSize = CGSize(
                width: 96 * displayScale,
                height: 96 * displayScale
            )
            thumbnail = await asset.thumbnail(size: targetSize)
        }
    }
}

#Preview {
    HomeView()
}

private actor LocationNameCache {
    static let shared = LocationNameCache()

    private var cache: [String: String] = [:]
    private var inflight: [String: Task<String?, Never>] = [:]

    func resolveLocationName(latitude: Double, longitude: Double) async -> String? {
        let key = String(format: "%.4f,%.4f", latitude, longitude)

        if let cached = cache[key] {
            return cached
        }

        if let runningTask = inflight[key] {
            return await runningTask.value
        }

        let task = Task<String?, Never> {
            let location = CLLocation(latitude: latitude, longitude: longitude)

            do {
                if #available(iOS 26.0, *) {
                    guard let request = MKReverseGeocodingRequest(location: location) else {
                        return nil
                    }
                    let mapItems = try await request.mapItems
                    guard let address = mapItems.first?.address else {
                        return nil
                    }
                    return address.shortAddress ?? address.fullAddress
                } else {
                    let geocoder = CLGeocoder()
                    let placemarks = try await geocoder.reverseGeocodeLocation(location)
                    guard let placemark = placemarks.first else {
                        return nil
                    }

                    let parts = [
                        placemark.subLocality,
                        placemark.locality,
                        placemark.administrativeArea,
                        placemark.country
                    ].compactMap { $0 }.filter { !$0.isEmpty }

                    guard !parts.isEmpty else {
                        return nil
                    }

                    return parts.joined(separator: ", ")
                }
            } catch {
                return nil
            }
        }

        inflight[key] = task
        let result = await task.value
        inflight[key] = nil

        if let result {
            cache[key] = result
        }

        return result
    }
}
