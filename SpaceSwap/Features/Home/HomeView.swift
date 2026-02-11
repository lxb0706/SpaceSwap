//
//  HomeView.swift
//  SpaceSwap
//
//  Created by 连晓彬 on 2026/2/9.
//

import SwiftUI
import Photos
import CoreLocation
import UIKit

public struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @State private var sortOption: SortOption = .sizeDescending
    @State private var pendingScanStart = false
    @State private var scanRippleAnimating = false
    @State private var canShowResults = false
    @State private var showDockingControl = true
    @State private var showCompletionState = false
    @State private var isDismissingScanControl = false
    @State private var showToolbarRescanButton = false
    @State private var shouldFlipProgress = false
    @State private var isNavBarCollapsed = false
    @State private var resultsTopBaseline: CGFloat?
    @State private var visibleAssetIDs: Set<String> = []
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
            return max(1, min(100, Int(viewModel.scanProgress * 100)))
        }
        return max(0, min(100, Int(viewModel.scanProgress * 100)))
    }

    private var isScanningVisualActive: Bool {
        viewModel.isScanning || pendingScanStart
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
                        .allowsHitTesting(!viewModel.isScanning)
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
                    scanRippleAnimating = true
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
                    scanRippleAnimating = false
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
                                    NavigationLink(destination: CompressionView(asset: asset)) {
                                        AssetRowView(asset: asset)
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
            triggerScan()
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
                    .trim(from: 0.0, to: showCompletionState ? 1.0 : max(viewModel.scanProgress, isScanningVisualActive ? 0.01 : 0.0))
                    .stroke(
                        Color.cyan,
                        style: StrokeStyle(lineWidth: 9, lineCap: .round, lineJoin: .round)
                    )
                    .frame(width: 178, height: 178)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: Color.cyan.opacity(0.55), radius: 10, x: 0, y: 0)
                    .opacity(isScanningVisualActive || showCompletionState ? 1.0 : 0.35)

                Circle()
                    .stroke(Color.blue.opacity(0.35), lineWidth: 2)
                    .frame(width: 190, height: 190)
                    .scaleEffect(scanRippleAnimating ? 1.1 : 0.92)
                    .opacity(scanRippleAnimating ? 0.22 : 0.0)
                    .animation(
                        .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                        value: scanRippleAnimating
                    )

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
        scanRippleAnimating = true
        showCompletionState = false
        isDismissingScanControl = false
        visibleAssetIDs = []
        viewModel.startScan()
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

    private func startStaggerReveal(for ids: [String]) {
        revealTask?.cancel()
        visibleAssetIDs = []

        guard !ids.isEmpty else { return }

        revealTask = Task { @MainActor in
            for id in ids {
                if Task.isCancelled { return }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
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
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.black.opacity(0.8))
                .frame(width: 34, height: 34)
                .background {
                    Circle()
                        .fill(Color.white.opacity(0.95))
                }
                .overlay(
                    Circle()
                        .stroke(Color.black.opacity(0.08), lineWidth: 0.9)
                )
                .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
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
    @State private var resolvedLocationName: String?
    @State private var didAnimateIn = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AssetThumbnailView(asset: asset)

            VStack(alignment: .leading, spacing: 6) {
                Text(asset.filename)
                    .font(.headline)
                    .lineLimit(1)

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
            let geocoder = CLGeocoder()
            let location = CLLocation(latitude: latitude, longitude: longitude)

            do {
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
