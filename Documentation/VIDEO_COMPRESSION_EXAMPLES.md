# Video Compression Examples - AVAssetExportSession

Comprehensive real-world examples for implementing video compression in SpaceSwap.

## Table of Contents
- [Basic AVAssetExportSession Setup](#basic-avassetexportsession-setup)
- [H.265/HEVC Encoding](#h265hevc-encoding)
- [Export Presets Configuration](#export-presets-configuration)
- [Progress Tracking](#progress-tracking)
- [Background Processing](#background-processing)
- [iCloud Download Handling](#icloud-download-handling)
- [Error Handling](#error-handling)
- [Complete Implementation Example](#complete-implementation-example)

---

## Basic AVAssetExportSession Setup

### Simple Export Session Creation
```swift
// Source: HXPhotoPicker/AssetManager+AVAssetExportSession.swift
func exportVideo(asset: AVAsset, to outputURL: URL, preset: String) {
    guard let exportSession = AVAssetExportSession(asset: asset, presetName: preset) else {
        print("Failed to create export session")
        return
    }
    
    exportSession.outputURL = outputURL
    exportSession.outputFileType = .mp4
    exportSession.shouldOptimizeForNetworkUse = true
    
    exportSession.exportAsynchronously {
        switch exportSession.status {
        case .completed:
            print("Export completed: \(outputURL)")
        case .failed:
            print("Export failed: \(exportSession.error?.localizedDescription ?? "")")
        case .cancelled:
            print("Export cancelled")
        default:
            break
        }
    }
}
```

### Checking Compatible Presets
```swift
// Source: HXPhotoPicker/AssetManager+AVAssetExportSession.swift
func selectCompatiblePreset(for asset: AVAsset, preferredPreset: String) -> String {
    let presets = AVAssetExportSession.exportPresets(compatibleWith: asset)
    
    if presets.contains(preferredPreset) {
        return preferredPreset
    } else if presets.contains(AVAssetExportPresetHighestQuality) {
        return AVAssetExportPresetHighestQuality
    } else if presets.contains(AVAssetExportPreset1280x720) {
        return AVAssetExportPreset1280x720
    } else {
        return AVAssetExportPresetMediumQuality
    }
}
```

---

## H.265/HEVC Encoding

### Photo Capture with HEVC
```swift
// Source: expo/expo camera module
var photoSettings = AVCapturePhotoSettings()

if photoOutput.availablePhotoCodecTypes.contains(AVVideoCodecType.hevc) {
    photoSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
}
```

### Video Recording with HEVC
```swift
// Source: damus camera service
if self.movieOutput.availableVideoCodecTypes.contains(.hevc) {
    var videoSettings = [String: Any]()
    videoSettings[AVVideoCodecKey] = AVVideoCodecType.hevc
    self.movieOutput.setOutputSettings(videoSettings, for: videoOutputConnection)
}
```

### HEVC with Alpha Channel Support
```swift
// Source: QuickRecorder
var videoSettings: [String: Any] = [
    AVVideoCodecKey: encoderIsH265 
        ? ((withAlpha && !recordHDR) ? AVVideoCodecType.hevcWithAlpha : AVVideoCodecType.hevc) 
        : AVVideoCodecType.h264,
    AVVideoWidthKey: width,
    AVVideoHeightKey: height,
    AVVideoCompressionPropertiesKey: [
        AVVideoProfileLevelKey: h265Level,
        AVVideoAverageBitRateKey: targetBitrate,
    ]
]
```

### HEVC Export Presets (iOS 11+)
```swift
// Source: AnyImageKit/VideoExportPreset.swift
case .h265_1920x1080:
    if #available(iOS 11.0, *), VideoExportPreset.isH265ExportPresetSupported() {
        return AVAssetExportPresetHEVC1920x1080
    } else {
        return AVAssetExportPreset1920x1080
    }
case .h265_3840x2160:
    if #available(iOS 11.0, *), VideoExportPreset.isH265ExportPresetSupported() {
        return AVAssetExportPresetHEVC3840x2160
    } else {
        return AVAssetExportPreset3840x2160
    }
```

---

## Export Presets Configuration

### Available Standard Presets
```swift
// Source: expo/expo ImagePickerOptions.swift
enum VideoQuality {
    case passthrough        // No compression
    case lowQuality        // AVAssetExportPresetLowQuality
    case mediumQuality     // AVAssetExportPresetMediumQuality
    case highestQuality    // AVAssetExportPresetHighestQuality
    case h264_640x480      // AVAssetExportPreset640x480
    case h264_960x540      // AVAssetExportPreset960x540
    case h264_1280x720     // AVAssetExportPreset1280x720
    case h264_1920x1080    // AVAssetExportPreset1920x1080
    case h264_3840x2160    // AVAssetExportPreset3840x2160
}

func toAVAssetExportPreset() -> String {
    switch self {
    case .passthrough:
        return AVAssetExportPresetPassthrough
    case .lowQuality:
        return AVAssetExportPresetLowQuality
    case .mediumQuality:
        return AVAssetExportPresetMediumQuality
    case .highestQuality:
        return AVAssetExportPresetHighestQuality
    case .h264_640x480:
        return AVAssetExportPreset640x480
    case .h264_960x540:
        return AVAssetExportPreset960x540
    case .h264_1280x720:
        return AVAssetExportPreset1280x720
    case .h264_1920x1080:
        return AVAssetExportPreset1920x1080
    case .h264_3840x2160:
        return AVAssetExportPreset3840x2160
    }
}
```

### Quality-Based Preset Selection
```swift
// Source: VideoCompress plugin
private func getExportPreset(_ quality: NSNumber) -> String {
    switch quality {
    case 1:
        return AVAssetExportPresetLowQuality    
    case 2:
        return AVAssetExportPresetMediumQuality
    case 3:
        return AVAssetExportPresetHighestQuality
    case 4:
        return AVAssetExportPreset640x480
    case 5:
        return AVAssetExportPreset960x540
    case 6:
        return AVAssetExportPreset1280x720
    case 7:
        return AVAssetExportPreset1920x1080
    default:
        return AVAssetExportPresetMediumQuality
    }
}
```

---

## Progress Tracking

### Timer-Based Progress Monitoring
```swift
// Source: YPImagePicker/LibraryMediaManager.swift
var exportTimer: Timer?

func startExport(exportSession: AVAssetExportSession) {
    exportTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
        if exportSession.progress > 0 {
            self?.updateProgress(exportSession.progress)
        }
        
        if exportSession.progress > 0.99 {
            timer.invalidate()
            self?.exportTimer = nil
            self?.updateProgress(0)
        }
    }
    
    exportSession.exportAsynchronously {
        self.exportTimer?.invalidate()
        self.exportTimer = nil
        // Handle completion
    }
}
```

### Progress with Async/Await
```swift
// Source: Automattic/pocket-casts-ios AudioClipExporter.swift
func exportAudio(from asset: AVAsset) async throws -> URL {
    let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A)!
    exportSession.outputFileType = .m4a
    
    let progress = Progress(totalUnitCount: 100)
    
    let progressObserver = Task {
        while !Task.isCancelled {
            progress.completedUnitCount = Int64(exportSession.progress * 100)
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1s
        }
    }
    
    await withTaskCancellationHandler {
        await exportSession.export()
    } onCancel: {
        exportSession.cancelExport()
    }
    
    progressObserver.cancel()
    
    guard exportSession.status == .completed else {
        throw ExportError.failed
    }
    
    return exportSession.outputURL!
}
```

### Progress Handler with Semaphore
```swift
// Source: keybase/client MediaUtils.swift
func exportVideo(exportSession: AVAssetExportSession, 
                 progress: ((Float) -> Void)?) throws {
    let semaphore = DispatchSemaphore(value: 0)
    var exportError: Error?
    
    if let progress = progress {
        let timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            DispatchQueue.main.async {
                progress(exportSession.progress)
            }
        }
        
        exportSession.exportAsynchronously {
            timer.invalidate()
            exportError = exportSession.error
            semaphore.signal()
        }
    } else {
        exportSession.exportAsynchronously {
            exportError = exportSession.error
            semaphore.signal()
        }
    }
    
    semaphore.wait()
    
    if let error = exportError {
        throw MediaUtilsError.videoProcessingFailed("Export failed: \(error.localizedDescription)")
    }
    
    guard exportSession.status == .completed else {
        throw MediaUtilsError.videoProcessingFailed("Export session failed with status: \(exportSession.status)")
    }
}
```

### RunLoop-Based Progress Tracking
```swift
// Source: Automattic/pocket-casts-ios VideoExporter.swift
func exportVideo(exportSession: AVAssetExportSession) async {
    let progress = Progress(totalUnitCount: 100)
    
    let timer = Timer(timeInterval: 0.01, repeats: true) { _ in
        progress.completedUnitCount = Int64(exportSession.progress * 100)
    }
    RunLoop.main.add(timer, forMode: .common)
    
    await withTaskCancellationHandler {
        await exportSession.export()
    } onCancel: {
        exportSession.cancelExport()
    }
    
    timer.invalidate()
}
```

---

## Background Processing

### Export Session Cancellation Support
```swift
// Source: ente native_video_editor plugin
class VideoEditorPlugin {
    private var currentExportSession: AVAssetExportSession?
    private var progressTimer: Timer?
    
    func trimVideo(inputPath: String, outputPath: String, 
                   startTime: Int, endTime: Int,
                   completion: @escaping (Result<URL, Error>) -> Void) {
        let asset = AVAsset(url: URL(fileURLWithPath: inputPath))
        
        guard let exportSession = AVAssetExportSession(asset: asset, 
                                                       presetName: AVAssetExportPresetHighestQuality) else {
            completion(.failure(VideoError.exportSessionCreationFailed))
            return
        }
        
        currentExportSession = exportSession
        exportSession.outputURL = URL(fileURLWithPath: outputPath)
        exportSession.outputFileType = .mp4
        
        let startCMTime = CMTime(seconds: Double(startTime) / 1000, preferredTimescale: 600)
        let endCMTime = CMTime(seconds: Double(endTime) / 1000, preferredTimescale: 600)
        exportSession.timeRange = CMTimeRange(start: startCMTime, end: endCMTime)
        
        startProgressReporting()
        
        exportSession.exportAsynchronously {
            DispatchQueue.main.async {
                self.stopProgressReporting()
                
                switch exportSession.status {
                case .completed:
                    completion(.success(exportSession.outputURL!))
                case .failed:
                    completion(.failure(exportSession.error ?? VideoError.unknown))
                case .cancelled:
                    completion(.failure(VideoError.cancelled))
                default:
                    completion(.failure(VideoError.unknown))
                }
                
                self.currentExportSession = nil
            }
        }
    }
    
    func cancelExport() {
        currentExportSession?.cancelExport()
        stopProgressReporting()
    }
    
    private func startProgressReporting() {
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let session = self?.currentExportSession else { return }
            // Report progress to UI
            self?.reportProgress(session.progress)
        }
    }
    
    private func stopProgressReporting() {
        progressTimer?.invalidate()
        progressTimer = nil
    }
}
```

### Background Processing with Multiple Sessions
```swift
// Source: YPImagePicker/LibraryMediaManager.swift
class LibraryMediaManager {
    internal var currentExportSessions: [AVAssetExportSession] = []
    
    func exportMultipleVideos(assets: [AVAsset], completion: @escaping ([URL]) -> Void) {
        var exportedURLs: [URL] = []
        let dispatchGroup = DispatchGroup()
        
        for asset in assets {
            dispatchGroup.enter()
            
            if let exportSession = AVAssetExportSession(asset: asset, 
                                                        presetName: AVAssetExportPresetMediumQuality) {
                currentExportSessions.append(exportSession)
                
                let outputURL = URL(fileURLWithPath: NSTemporaryDirectory())
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension("mp4")
                
                exportSession.outputURL = outputURL
                exportSession.outputFileType = .mp4
                exportSession.shouldOptimizeForNetworkUse = true
                
                exportSession.exportAsynchronously {
                    if exportSession.status == .completed {
                        exportedURLs.append(outputURL)
                    }
                    dispatchGroup.leave()
                }
            } else {
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            self.currentExportSessions.removeAll()
            completion(exportedURLs)
        }
    }
    
    func cancelAllExports() {
        currentExportSessions.forEach { $0.cancelExport() }
        currentExportSessions.removeAll()
    }
}
```

---

## iCloud Download Handling

### Two-Stage Request Pattern (Local First, iCloud if Needed)
```swift
// Source: HXPhotoPicker/AssetManager+AVAsset.swift
func requestAVAsset(
    for asset: PHAsset,
    progressHandler: PHAssetImageProgressHandler?,
    completionHandler: @escaping (Result<AVAsset, Error>) -> Void
) -> PHImageRequestID {
    let version = PHVideoRequestOptionsVersion.current
    let deliveryMode = PHVideoRequestOptionsDeliveryMode.highQualityFormat
    
    // Stage 1: Try local asset first (isNetworkAccessAllowed = false)
    return requestAVAsset(
        for: asset,
        version: version,
        deliveryMode: deliveryMode,
        isNetworkAccessAllowed: false,
        progressHandler: nil
    ) { result in
        DispatchQueue.main.async {
            switch result {
            case .success(let avAsset):
                completionHandler(.success(avAsset))
            case .failure(let error):
                switch error {
                case .needSyncICloud:
                    // Stage 2: Asset is in iCloud, download it
                    let iCloudRequestID = self.requestAVAsset(
                        for: asset,
                        version: version,
                        deliveryMode: deliveryMode,
                        isNetworkAccessAllowed: true,
                        progressHandler: progressHandler
                    ) { result in
                        DispatchQueue.main.async {
                            completionHandler(result)
                        }
                    }
                    // Store iCloudRequestID if needed for cancellation
                default:
                    completionHandler(.failure(error))
                }
            }
        }
    }
}
```

### Direct PHImageManager Request with iCloud Support
```swift
// Source: HXPhotoPicker/AssetManager+AVAsset.swift
func requestAVAsset(
    for asset: PHAsset,
    isNetworkAccessAllowed: Bool,
    progressHandler: PHAssetImageProgressHandler?
) -> PHImageRequestID {
    let options = PHVideoRequestOptions()
    options.isNetworkAccessAllowed = isNetworkAccessAllowed
    options.version = .current
    options.deliveryMode = .highQualityFormat
    options.progressHandler = progressHandler
    
    return PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { 
        avAsset, audioMix, info in
        
        guard let info = info else { return }
        
        // Check if asset is in iCloud and needs download
        let isInCloud = (info[PHImageResultIsInCloudKey] as? Bool) ?? false
        let isDownloadFinished = !(info[PHImageCancelledKey] as? Bool ?? false)
        let downloadError = info[PHImageErrorKey] as? Error
        
        if isInCloud && !isNetworkAccessAllowed {
            // Asset is in iCloud but we haven't allowed network access
            // Caller should retry with isNetworkAccessAllowed = true
        }
        
        if let avAsset = avAsset, isDownloadFinished {
            // Success
        } else if let error = downloadError {
            // Handle error
        }
    }
}
```

### PHAssetResourceManager for iCloud Downloads
```swift
// Source: expo/expo MediaHandler.swift
func downloadLivePhotoFromiCloud(for asset: PHAsset) async throws -> (URL, URL) {
    let resources = PHAssetResource.assetResources(for: asset)
    
    guard let photoResource = resources.first(where: { $0.type == .photo }),
          let videoResource = resources.first(where: { $0.type == .pairedVideo }) else {
        throw PhotoError.resourceNotFound
    }
    
    let photoURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("jpg")
    
    let videoURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("mov")
    
    // PHAssetResourceManager automatically handles iCloud downloads
    let options = PHAssetResourceRequestOptions()
    options.isNetworkAccessAllowed = true
    
    try await PHAssetResourceManager.default().writeData(
        for: photoResource,
        toFile: photoURL,
        options: options
    )
    
    try await PHAssetResourceManager.default().writeData(
        for: videoResource,
        toFile: videoURL,
        options: options
    )
    
    return (photoURL, videoURL)
}
```

### Network Access with Progress Tracking
```swift
// Source: longitachi/ZLPhotoBrowser ZLPhotoManager.swift
func requestImageData(
    for asset: PHAsset,
    progress: ((CGFloat, Error?, UnsafeMutablePointer<ObjCBool>, [AnyHashable: Any]?) -> Void)?
) {
    let option = PHImageRequestOptions()
    option.isNetworkAccessAllowed = true
    option.resizeMode = .fast
    option.deliveryMode = .highQualityFormat
    
    option.progressHandler = { pro, error, stop, info in
        DispatchQueue.main.async {
            progress?(CGFloat(pro), error, stop, info)
        }
    }
    
    PHImageManager.default().requestImageDataAndOrientation(
        for: asset,
        options: option
    ) { data, dataUTI, orientation, info in
        // Process image data
    }
}
```

### Checking if Asset is Available Locally
```swift
// Source: TelegramMessenger/Telegram-iOS FetchAssets.swift
func isAssetAvailableLocally(asset: PHAsset) -> Signal<Bool, NoError> {
    return Signal { subscriber in
        let requestId: PHImageRequestID
        
        if case .video = asset.mediaType {
            let options = PHVideoRequestOptions()
            options.isNetworkAccessAllowed = false // Only check local
            
            requestId = PHImageManager.default().requestAVAsset(
                forVideo: asset,
                options: options
            ) { asset, _, _ in
                subscriber.putNext(asset != nil)
                subscriber.putCompletion()
            }
        } else {
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = false
            
            requestId = PHImageManager.default().requestImageDataAndOrientation(
                for: asset,
                options: options
            ) { data, _, _, _ in
                subscriber.putNext(data != nil)
                subscriber.putCompletion()
            }
        }
        
        return ActionDisposable {
            PHImageManager.default().cancelImageRequest(requestId)
        }
    }
}
```

---

## Error Handling

### Comprehensive Status Checking
```swift
// Source: HXPhotoPicker/AssetManager+AVAssetExportSession.swift
func exportVideo(exportSession: AVAssetExportSession, 
                 to fileURL: URL,
                 completion: @escaping (Result<URL, AssetError>) -> Void) {
    exportSession.exportAsynchronously {
        DispatchQueue.main.async {
            switch exportSession.status {
            case .completed:
                completion(.success(fileURL))
            case .failed:
                let error = AssetError.exportFailed(exportSession.error)
                completion(.failure(error))
            case .cancelled:
                let error = AssetError.exportCancelled
                completion(.failure(error))
            default:
                break
            }
        }
    }
}

enum AssetError: Error {
    case exportFailed(Error?)
    case exportCancelled
    case needSyncICloud
    case networkError
    case unsupportedFormat
    
    var localizedDescription: String {
        switch self {
        case .exportFailed(let underlyingError):
            if let error = underlyingError {
                return "Export failed: \(error.localizedDescription)"
            }
            return "Export failed"
        case .exportCancelled:
            return "Export was cancelled"
        case .needSyncICloud:
            return "Asset needs to be downloaded from iCloud"
        case .networkError:
            return "Network connection required"
        case .unsupportedFormat:
            return "Video format not supported"
        }
    }
}
```

### Info Dictionary Analysis
```swift
// Source: HXPhotoPicker/AssetManager+AVAsset.swift
extension AssetManager {
    static func assetDownloadError(for info: [AnyHashable: Any]?) -> Bool {
        guard let info = info else { return false }
        return info[PHImageErrorKey] != nil
    }
    
    static func assetIsInCloud(for info: [AnyHashable: Any]?) -> Bool {
        guard let info = info else { return false }
        if let isInCloud = info[PHImageResultIsInCloudKey] as? Bool, isInCloud {
            return true
        }
        return false
    }
    
    static func assetDownloadFinined(for info: [AnyHashable: Any]?) -> Bool {
        guard let info = info else { return false }
        if let isCancelled = info[PHImageCancelledKey] as? Bool, isCancelled {
            return false
        }
        return true
    }
    
    static func assetIsDegraded(for info: [AnyHashable: Any]?) -> Bool {
        guard let info = info else { return false }
        if let isDegraded = info[PHImageResultIsDegradedKey] as? Bool, isDegraded {
            return true
        }
        return false
    }
}
```

### File Management Error Handling
```swift
// Source: Signal-iOS PreviewableAttachment.swift
func exportVideo(exportSession: AVAssetExportSession, to outputURL: URL) async throws {
    // Clean up existing file if it exists
    try? FileManager.default.removeItem(at: outputURL)
    
    await exportSession.export()
    
    guard exportSession.status == .completed else {
        switch exportSession.status {
        case .failed:
            throw ExportError.failed(exportSession.error)
        case .cancelled:
            throw ExportError.cancelled
        default:
            throw ExportError.unknown
        }
    }
    
    // Verify output file exists
    guard FileManager.default.fileExists(atPath: outputURL.path) else {
        throw ExportError.outputFileNotFound
    }
    
    // Verify output file size
    let attributes = try FileManager.default.attributesOfItem(atPath: outputURL.path)
    guard let fileSize = attributes[.size] as? Int, fileSize > 0 else {
        throw ExportError.outputFileEmpty
    }
}
```

---

## Complete Implementation Example

### Production-Ready Video Compressor
```swift
// Inspired by HXPhotoPicker and Signal-iOS implementations

import AVFoundation
import Photos

class VideoCompressor {
    
    // MARK: - Types
    
    enum CompressionQuality {
        case low
        case medium
        case high
        case h265_720p
        case h265_1080p
        
        var preset: String {
            switch self {
            case .low:
                return AVAssetExportPresetLowQuality
            case .medium:
                return AVAssetExportPresetMediumQuality
            case .high:
                return AVAssetExportPreset1920x1080
            case .h265_720p:
                if #available(iOS 11.0, *) {
                    return AVAssetExportPresetHEVC1920x1080
                }
                return AVAssetExportPreset1280x720
            case .h265_1080p:
                if #available(iOS 11.0, *) {
                    return AVAssetExportPresetHEVC1920x1080
                }
                return AVAssetExportPreset1920x1080
            }
        }
    }
    
    enum CompressionError: Error {
        case exportSessionCreationFailed
        case exportFailed(Error?)
        case exportCancelled
        case needsICloudDownload
        case assetLoadFailed
        case outputFileError
        
        var localizedDescription: String {
            switch self {
            case .exportSessionCreationFailed:
                return "Failed to create export session"
            case .exportFailed(let error):
                return "Export failed: \(error?.localizedDescription ?? "Unknown error")"
            case .exportCancelled:
                return "Export was cancelled"
            case .needsICloudDownload:
                return "Video needs to be downloaded from iCloud"
            case .assetLoadFailed:
                return "Failed to load video asset"
            case .outputFileError:
                return "Output file is invalid"
            }
        }
    }
    
    struct CompressionResult {
        let outputURL: URL
        let originalSize: Int64
        let compressedSize: Int64
        let compressionRatio: Double
        let duration: TimeInterval
        
        var savedBytes: Int64 {
            return originalSize - compressedSize
        }
        
        var savedPercentage: Double {
            return (Double(savedBytes) / Double(originalSize)) * 100
        }
    }
    
    // MARK: - Properties
    
    private var currentExportSession: AVAssetExportSession?
    private var progressTimer: Timer?
    
    // MARK: - Public Methods
    
    /// Compress a PHAsset video
    func compress(
        asset: PHAsset,
        quality: CompressionQuality,
        progressHandler: ((Float) -> Void)? = nil
    ) async throws -> CompressionResult {
        // Load AVAsset from PHAsset (handles iCloud if needed)
        let avAsset = try await loadAVAsset(from: asset, progressHandler: progressHandler)
        
        // Get original file size
        let originalSize = try await getFileSize(for: asset)
        
        // Compress
        let outputURL = generateOutputURL()
        let startTime = Date()
        
        try await compress(
            avAsset: avAsset,
            to: outputURL,
            quality: quality,
            progressHandler: progressHandler
        )
        
        let duration = Date().timeIntervalSince(startTime)
        
        // Get compressed file size
        let compressedSize = try getFileSize(at: outputURL)
        
        return CompressionResult(
            outputURL: outputURL,
            originalSize: originalSize,
            compressedSize: compressedSize,
            compressionRatio: Double(compressedSize) / Double(originalSize),
            duration: duration
        )
    }
    
    /// Compress an AVAsset directly
    func compress(
        avAsset: AVAsset,
        to outputURL: URL,
        quality: CompressionQuality,
        progressHandler: ((Float) -> Void)? = nil
    ) async throws {
        // Select compatible preset
        let preset = selectCompatiblePreset(for: avAsset, preferredPreset: quality.preset)
        
        // Create export session
        guard let exportSession = AVAssetExportSession(asset: avAsset, presetName: preset) else {
            throw CompressionError.exportSessionCreationFailed
        }
        
        // Configure export session
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true
        
        // Remove existing file
        try? FileManager.default.removeItem(at: outputURL)
        
        // Store current session for cancellation
        currentExportSession = exportSession
        
        // Start progress monitoring
        if let progressHandler = progressHandler {
            startProgressMonitoring(exportSession: exportSession, handler: progressHandler)
        }
        
        // Export
        await exportSession.export()
        
        // Stop progress monitoring
        stopProgressMonitoring()
        
        // Check result
        guard exportSession.status == .completed else {
            switch exportSession.status {
            case .failed:
                throw CompressionError.exportFailed(exportSession.error)
            case .cancelled:
                throw CompressionError.exportCancelled
            default:
                throw CompressionError.exportFailed(nil)
            }
        }
        
        // Verify output
        try verifyOutput(at: outputURL)
        
        currentExportSession = nil
    }
    
    /// Cancel ongoing compression
    func cancel() {
        currentExportSession?.cancelExport()
        stopProgressMonitoring()
        currentExportSession = nil
    }
    
    // MARK: - Private Methods
    
    private func loadAVAsset(
        from asset: PHAsset,
        progressHandler: ((Float) -> Void)?
    ) async throws -> AVAsset {
        return try await withCheckedThrowingContinuation { continuation in
            // Try local first
            requestAVAsset(
                for: asset,
                isNetworkAccessAllowed: false,
                progressHandler: nil
            ) { result in
                switch result {
                case .success(let avAsset):
                    continuation.resume(returning: avAsset)
                case .failure(let error):
                    if case .needsICloudDownload = error {
                        // Retry with iCloud download
                        self.requestAVAsset(
                            for: asset,
                            isNetworkAccessAllowed: true,
                            progressHandler: progressHandler
                        ) { result in
                            continuation.resume(with: result)
                        }
                    } else {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
    
    private func requestAVAsset(
        for asset: PHAsset,
        isNetworkAccessAllowed: Bool,
        progressHandler: ((Float) -> Void)?,
        completion: @escaping (Result<AVAsset, CompressionError>) -> Void
    ) {
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = isNetworkAccessAllowed
        options.version = .current
        options.deliveryMode = .highQualityFormat
        
        if isNetworkAccessAllowed {
            options.progressHandler = { progress, error, stop, info in
                DispatchQueue.main.async {
                    progressHandler?(Float(progress))
                }
            }
        }
        
        PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, info in
            DispatchQueue.main.async {
                guard let info = info else {
                    completion(.failure(.assetLoadFailed))
                    return
                }
                
                // Check for errors
                if let error = info[PHImageErrorKey] as? Error {
                    completion(.failure(.exportFailed(error)))
                    return
                }
                
                // Check if cancelled
                if let cancelled = info[PHImageCancelledKey] as? Bool, cancelled {
                    completion(.failure(.exportCancelled))
                    return
                }
                
                // Check if in iCloud and not downloaded
                if let isInCloud = info[PHImageResultIsInCloudKey] as? Bool,
                   isInCloud && !isNetworkAccessAllowed {
                    completion(.failure(.needsICloudDownload))
                    return
                }
                
                // Success
                if let avAsset = avAsset {
                    completion(.success(avAsset))
                } else {
                    completion(.failure(.assetLoadFailed))
                }
            }
        }
    }
    
    private func selectCompatiblePreset(for asset: AVAsset, preferredPreset: String) -> String {
        let presets = AVAssetExportSession.exportPresets(compatibleWith: asset)
        
        if presets.contains(preferredPreset) {
            return preferredPreset
        } else if presets.contains(AVAssetExportPresetHighestQuality) {
            return AVAssetExportPresetHighestQuality
        } else if presets.contains(AVAssetExportPreset1280x720) {
            return AVAssetExportPreset1280x720
        } else {
            return AVAssetExportPresetMediumQuality
        }
    }
    
    private func startProgressMonitoring(
        exportSession: AVAssetExportSession,
        handler: @escaping (Float) -> Void
    ) {
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            handler(exportSession.progress)
        }
    }
    
    private func stopProgressMonitoring() {
        progressTimer?.invalidate()
        progressTimer = nil
    }
    
    private func verifyOutput(at url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw CompressionError.outputFileError
        }
        
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard let fileSize = attributes[.size] as? Int64, fileSize > 0 else {
            throw CompressionError.outputFileError
        }
    }
    
    private func getFileSize(for asset: PHAsset) async throws -> Int64 {
        let resources = PHAssetResource.assetResources(for: asset)
        guard let videoResource = resources.first(where: { $0.type == .video }) else {
            throw CompressionError.assetLoadFailed
        }
        
        if let fileSize = videoResource.value(forKey: "fileSize") as? Int64 {
            return fileSize
        }
        
        // Fallback: estimate from data
        return try await withCheckedThrowingContinuation { continuation in
            var totalSize: Int64 = 0
            let options = PHAssetResourceRequestOptions()
            options.isNetworkAccessAllowed = true
            
            PHAssetResourceManager.default().requestData(
                for: videoResource,
                options: options,
                dataReceivedHandler: { data in
                    totalSize += Int64(data.count)
                },
                completionHandler: { error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: totalSize)
                    }
                }
            )
        }
    }
    
    private func getFileSize(at url: URL) throws -> Int64 {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return attributes[.size] as? Int64 ?? 0
    }
    
    private func generateOutputURL() -> URL {
        let fileName = "compressed_\(UUID().uuidString).mp4"
        return FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
    }
}
```

### Usage Example
```swift
// Compress a video from Photos library
let compressor = VideoCompressor()

Task {
    do {
        let result = try await compressor.compress(
            asset: videoAsset,
            quality: .h265_1080p,
            progressHandler: { progress in
                print("Progress: \(Int(progress * 100))%")
            }
        )
        
        print("Compression completed!")
        print("Original size: \(result.originalSize) bytes")
        print("Compressed size: \(result.compressedSize) bytes")
        print("Saved: \(result.savedPercentage)%")
        print("Output: \(result.outputURL.path)")
        
    } catch {
        print("Compression failed: \(error.localizedDescription)")
    }
}

// Cancel if needed
// compressor.cancel()
```

---

## Key Recommendations for SpaceSwap

1. **Use Two-Stage iCloud Handling**: Always try local first, then iCloud if needed
2. **Implement Progress Tracking**: Use Timer-based monitoring for responsive UI
3. **Support Cancellation**: Store export sessions and provide cancel functionality
4. **Prefer H.265 for Better Compression**: Check availability and fallback to H.264
5. **Verify Output Files**: Always check file existence and size after export
6. **Handle Background Processing**: Support app backgrounding during compression
7. **Use Appropriate Presets**: Match presets to device capabilities and user needs
8. **Estimate Compression Savings**: Show users potential space savings before compression

## Additional Resources

- [HXPhotoPicker](https://github.com/SilenceLove/HXPhotoPicker) - Comprehensive photo/video picker with compression
- [Signal-iOS](https://github.com/signalapp/Signal-iOS) - Production video compression for messaging
- [expo/expo](https://github.com/expo/expo) - React Native media handling with native iOS implementation
- [YPImagePicker](https://github.com/Yummypets/YPImagePicker) - Media picker with built-in compression

---

Generated: 2026-02-09
For: SpaceSwap iOS App
