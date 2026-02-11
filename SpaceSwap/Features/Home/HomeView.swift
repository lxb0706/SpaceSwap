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
    @State private var showDockingControl = true
    @State private var dockToTopRight = false
    @State private var showCompletionState = false
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
        max(0, min(100, Int(viewModel.scanProgress * 100)))
    }

    public var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                ZStack(alignment: .topLeading) {
                    content

                    if showDockingControl {
                        scanControl
                            .position(scanControlPosition(in: proxy))
                            .scaleEffect(dockToTopRight ? 0.32 : 1.0)
                            .opacity(dockToTopRight ? 0.88 : 1.0)
                            .animation(.spring(response: 0.55, dampingFraction: 0.82), value: dockToTopRight)
                            .animation(.easeInOut(duration: 0.25), value: viewModel.scanProgress)
                            .animation(.easeInOut(duration: 0.2), value: showCompletionState)
                            .allowsHitTesting(!viewModel.isScanning && !dockToTopRight)
                    }
                }
                .onAppear {
                    isPulseAnimating = true
                }
            }
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !viewModel.isScanning, !viewModel.scannedAssets.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            triggerScan()
                        } label: {
                            Image(systemName: "arrow.clockwise.circle.fill")
                                .font(.title3)
                                .symbolRenderingMode(.hierarchical)
                        }
                        .accessibilityLabel("Rescan Photo Library")
                    }
                }
            }
            .onChange(of: viewModel.isScanning) { oldValue, newValue in
                if !oldValue && newValue {
                    transitionTask?.cancel()
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                        showDockingControl = true
                        dockToTopRight = false
                        showCompletionState = false
                    }
                }

                if oldValue && !newValue {
                    handleScanFinished()
                }
            }
        }
    }

    private var content: some View {
        VStack(spacing: 16) {
            if viewModel.scannedAssets.isEmpty {
                Spacer()
                VStack(spacing: 10) {
                    Text("Space Swap")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text(viewModel.isScanning ? "Scanning your photo library..." : "Scan your photo library for large videos")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    if viewModel.isScanning {
                        Text("Progress updates as assets are analyzed")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 24)
                Spacer()
            } else {
                VStack(spacing: 12) {
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
                    .padding(.horizontal, 16)

                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(sortedAssets) { asset in
                                NavigationLink(destination: CompressionView(asset: asset)) {
                                    AssetRowView(asset: asset)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 100)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea(.container, edges: .bottom)
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
                            colors: showCompletionState ? [Color.green, Color.teal] : [Color.blue, Color.cyan],
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
                    .trim(from: 0.0, to: showCompletionState ? 1.0 : max(viewModel.scanProgress, viewModel.isScanning ? 0.01 : 0.0))
                    .stroke(
                        showCompletionState ? Color.green : Color.cyan,
                        style: StrokeStyle(lineWidth: 9, lineCap: .round, lineJoin: .round)
                    )
                    .frame(width: 178, height: 178)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: Color.cyan.opacity(0.55), radius: 10, x: 0, y: 0)

                Circle()
                    .stroke(Color.blue.opacity(0.35), lineWidth: 2)
                    .frame(width: 190, height: 190)
                    .scaleEffect(isPulseAnimating ? 1.08 : 0.93)
                    .opacity(isPulseAnimating ? 0.2 : 0.7)
                    .animation(
                        .easeInOut(duration: 1.35).repeatForever(autoreverses: true),
                        value: isPulseAnimating
                    )

                VStack(spacing: 6) {
                    if showCompletionState {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 30, weight: .semibold))
                    } else if viewModel.isScanning {
                        Text("\(scanProgressPercent)%")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
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

    private func scanControlPosition(in proxy: GeometryProxy) -> CGPoint {
        let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
        let topRight = CGPoint(x: proxy.size.width - 34, y: proxy.safeAreaInsets.top + 24)
        return dockToTopRight ? topRight : center
    }

    private func triggerScan() {
        transitionTask?.cancel()
        withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
            showDockingControl = true
            dockToTopRight = false
            showCompletionState = false
        }
        viewModel.startScan()
    }

    private func handleScanFinished() {
        guard !viewModel.scannedAssets.isEmpty else {
            withAnimation(.easeInOut(duration: 0.25)) {
                showCompletionState = false
                dockToTopRight = false
                showDockingControl = true
            }
            return
        }

        transitionTask?.cancel()
        transitionTask = Task { @MainActor in
            withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) {
                showCompletionState = true
            }

            try? await Task.sleep(nanoseconds: 700_000_000)

            withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
                dockToTopRight = true
            }

            try? await Task.sleep(nanoseconds: 480_000_000)

            withAnimation(.easeOut(duration: 0.25)) {
                showDockingControl = false
                showCompletionState = false
            }
        }
    }
}

private struct AssetRowView: View {
    let asset: PhotoAsset

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AssetThumbnailView(asset: asset)

            VStack(alignment: .leading, spacing: 6) {
                Text(asset.filename)
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: 12) {
                    Label(asset.fileSize.formattedBytes, systemImage: "internaldrive")
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

                if let locationText = asset.locationText {
                    Label(locationText, systemImage: "mappin.and.ellipse")
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
    }
}

private struct AssetThumbnailView: View {
    let asset: PhotoAsset
    @State private var thumbnail: UIImage?

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
            thumbnail = await asset.thumbnail(size: CGSize(width: 240, height: 240))
        }
    }
}

#Preview {
    HomeView()
}
