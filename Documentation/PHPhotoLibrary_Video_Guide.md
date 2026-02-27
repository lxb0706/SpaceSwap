# PHPhotoLibrary Video Management Guide for iOS

Complete guide for working with videos in PHPhotoLibrary, including scanning, file size retrieval, iCloud handling, and PHAsset management for video compression apps.

## Table of Contents
1. [Overview](#overview)
2. [Scanning Videos from PHPhotoLibrary](#scanning-videos)
3. [Fetching File Sizes Asynchronously](#fetching-file-sizes)
4. [Handling iCloud Assets](#handling-icloud-assets)
5. [PHAsset Video Management](#phasset-video-management)
6. [Complete Examples](#complete-examples)
7. [Official Apple Resources](#official-apple-resources)

---

## Overview

PhotoKit is Apple's framework for working with the Photos library. Key components:
- **PHPhotoLibrary**: Manages access to the entire photo library
- **PHAsset**: Represents a single photo or video asset
- **PHAssetResource**: Provides access to underlying data resources
- **PHImageManager**: Handles requests for asset data
- **PHAssetResourceManager**: Manages resource data requests

---

## Scanning Videos from PHPhotoLibrary

### Basic Video Fetching

```swift
import Photos

func fetchAllVideos() -> PHFetchResult<PHAsset> {
    let fetchOptions = PHFetchOptions()
    fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
    
    // Fetch all video assets
    let videos = PHAsset.fetchAssets(with: .video, options: fetchOptions)
    return videos
}
```

### Authorization

```swift
func requestPhotoLibraryAccess(completion: @escaping (Bool) -> Void) {
    PHPhotoLibrary.requestAuthorization { status in
        DispatchQueue.main.async {
            completion(status == .authorized)
        }
    }
}

// iOS 14+: Request with access level
func requestPhotoLibraryAccessLevel(completion: @escaping (Bool) -> Void) {
    if #available(iOS 14, *) {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            DispatchQueue.main.async {
                completion(status == .authorized)
            }
        }
    } else {
        requestPhotoLibraryAccess(completion: completion)
    }
}
```

### Filtering Videos by Size

```swift
func fetchLargeVideos(minimumSizeMB: Int, completion: @escaping ([PHAsset]) -> Void) {
    let fetchOptions = PHFetchOptions()
    fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
    
    let allVideos = PHAsset.fetchAssets(with: .video, options: fetchOptions)
    var largeVideos: [PHAsset] = []
    
    allVideos.enumerateObjects { asset, _, _ in
        let resources = PHAssetResource.assetResources(for: asset)
        
        if let resource = resources.first(where: { $0.type == .video || $0.type == .fullSizeVideo }) {
            // Get file size using KVO (unofficial but widely used)
            if let fileSize = resource.value(forKey: "fileSize") as? Int64 {
                let sizeMB = fileSize / (1024 * 1024)
                if sizeMB >= minimumSizeMB {
                    largeVideos.append(asset)
                }
            }
        }
    }
    
    completion(largeVideos)
}
```

---

## Fetching File Sizes Asynchronously

### Method 1: Using PHAssetResource (Quick, Approximate)

```swift
func getVideoFileSize(for asset: PHAsset) -> Int64? {
    let resources = PHAssetResource.assetResources(for: asset)
    
    // Prefer fullSizeVideo if available
    guard let resource = resources.first(where: { $0.type == .fullSizeVideo }) 
                      ?? resources.first(where: { $0.type == .video }) else {
        return nil
    }
    
    // Note: This uses KVO to access an unofficial property
    // May not reflect exact file size for iCloud assets not downloaded
    if let fileSize = resource.value(forKey: "fileSize") as? Int64 {
        return fileSize
    }
    
    return nil
}
```

### Method 2: Using AVAsset (Accurate, Requires Download)

```swift
func requestAccurateVideoFileSize(
    for asset: PHAsset,
    completion: @escaping (Int64?) -> Void
) {
    let options = PHVideoRequestOptions()
    options.isNetworkAccessAllowed = true
    options.version = .current
    
    PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, info in
        guard let urlAsset = avAsset as? AVURLAsset else {
            completion(nil)
            return
        }
        
        do {
            let fileSize = try urlAsset.url.resourceValues(forKeys: [.fileSizeKey]).fileSize
            completion(Int64(fileSize ?? 0))
        } catch {
            completion(nil)
        }
    }
}
```

### Method 3: Using PHAssetResourceManager (Most Accurate)

```swift
func requestExactVideoFileSize(
    for asset: PHAsset,
    completion: @escaping (Int64) -> Void
) {
    let resources = PHAssetResource.assetResources(for: asset)
    
    guard let resource = resources.first(where: { $0.type == .fullSizeVideo })
                      ?? resources.first(where: { $0.type == .video }) else {
        completion(0)
        return
    }
    
    var totalSize: Int64 = 0
    let options = PHAssetResourceRequestOptions()
    options.isNetworkAccessAllowed = true
    
    PHAssetResourceManager.default().requestData(
        for: resource,
        options: options,
        dataReceivedHandler: { data in
            totalSize += Int64(data.count)
        },
        completionHandler: { error in
            DispatchQueue.main.async {
                if error == nil {
                    completion(totalSize)
                } else {
                    completion(0)
                }
            }
        }
    )
}
```

---

## Handling iCloud Assets

### Checking if Asset is in iCloud

```swift
extension PHAsset {
    var isStoredInCloud: Bool {
        let resources = PHAssetResource.assetResources(for: self)
        return resources.first?.value(forKey: "locallyAvailable") as? Bool == false
    }
    
    var isLocallyAvailable: Bool? {
        let resourceArray = PHAssetResource.assetResources(for: self)
        return resourceArray.first?.value(forKey: "locallyAvailable") as? Bool
    }
}
```

### Downloading iCloud Videos with Progress

```swift
func downloadVideoFromiCloud(
    asset: PHAsset,
    progressHandler: @escaping (Double) -> Void,
    completion: @escaping (Bool, Error?) -> Void
) -> PHImageRequestID {
    let options = PHVideoRequestOptions()
    options.isNetworkAccessAllowed = true
    options.deliveryMode = .highQualityFormat
    
    // Progress handler for iCloud download
    options.progressHandler = { progress, error, stop, info in
        DispatchQueue.main.async {
            progressHandler(progress)
        }
    }
    
    return PHImageManager.default().requestAVAsset(
        forVideo: asset,
        options: options
    ) { avAsset, audioMix, info in
        DispatchQueue.main.async {
            let error = info?[PHImageErrorKey] as? Error
            completion(avAsset != nil, error)
        }
    }
}
```

### Checking iCloud Download Status Before Requesting

```swift
func checkVideoAvailability(
    for asset: PHAsset,
    completion: @escaping (Bool) -> Void
) {
    let options = PHVideoRequestOptions()
    options.isNetworkAccessAllowed = false  // Only check local
    options.deliveryMode = .fastFormat
    
    PHImageManager.default().requestAVAsset(
        forVideo: asset,
        options: options
    ) { avAsset, _, _ in
        DispatchQueue.main.async {
            completion(avAsset != nil)
        }
    }
}
```

### Complete iCloud Video Handler

```swift
class VideoiCloudHandler {
    private var downloadRequests: [String: PHImageRequestID] = [:]
    
    func downloadVideoIfNeeded(
        asset: PHAsset,
        progressHandler: @escaping (Double, Error?) -> Void,
        completion: @escaping (AVAsset?, Error?) -> Void
    ) {
        // First check if locally available
        let checkOptions = PHVideoRequestOptions()
        checkOptions.isNetworkAccessAllowed = false
        
        PHImageManager.default().requestAVAsset(
            forVideo: asset,
            options: checkOptions
        ) { [weak self] avAsset, _, info in
            if avAsset != nil {
                // Already available locally
                completion(avAsset, nil)
            } else {
                // Need to download from iCloud
                self?.downloadFromiCloud(
                    asset: asset,
                    progressHandler: progressHandler,
                    completion: completion
                )
            }
        }
    }
    
    private func downloadFromiCloud(
        asset: PHAsset,
        progressHandler: @escaping (Double, Error?) -> Void,
        completion: @escaping (AVAsset?, Error?) -> Void
    ) {
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat
        
        options.progressHandler = { progress, error, stop, info in
            DispatchQueue.main.async {
                progressHandler(progress, error)
            }
        }
        
        let requestID = PHImageManager.default().requestAVAsset(
            forVideo: asset,
            options: options
        ) { avAsset, _, info in
            DispatchQueue.main.async {
                let error = info?[PHImageErrorKey] as? Error
                completion(avAsset, error)
            }
        }
        
        downloadRequests[asset.localIdentifier] = requestID
    }
    
    func cancelDownload(for asset: PHAsset) {
        if let requestID = downloadRequests[asset.localIdentifier] {
            PHImageManager.default().cancelImageRequest(requestID)
            downloadRequests.removeValue(forKey: asset.localIdentifier)
        }
    }
}
```

---

## PHAsset Video Management

### Getting Video Metadata

```swift
struct VideoMetadata {
    let duration: TimeInterval
    let width: Int
    let height: Int
    let fileSize: Int64
    let creationDate: Date?
    let modificationDate: Date?
    let originalFilename: String?
    let isFavorite: Bool
    let isInCloud: Bool
}

func getVideoMetadata(for asset: PHAsset) -> VideoMetadata? {
    guard asset.mediaType == .video else { return nil }
    
    let resources = PHAssetResource.assetResources(for: asset)
    let resource = resources.first(where: { $0.type == .video || $0.type == .fullSizeVideo })
    
    let fileSize = resource?.value(forKey: "fileSize") as? Int64 ?? 0
    let isInCloud = resource?.value(forKey: "locallyAvailable") as? Bool == false
    
    return VideoMetadata(
        duration: asset.duration,
        width: asset.pixelWidth,
        height: asset.pixelHeight,
        fileSize: fileSize,
        creationDate: asset.creationDate,
        modificationDate: asset.modificationDate,
        originalFilename: resource?.originalFilename,
        isFavorite: asset.isFavorite,
        isInCloud: isInCloud
    )
}
```

### Exporting Video for Compression

```swift
func exportVideoForCompression(
    asset: PHAsset,
    completion: @escaping (URL?, Error?) -> Void
) {
    let options = PHVideoRequestOptions()
    options.isNetworkAccessAllowed = true
    options.version = .current
    options.deliveryMode = .highQualityFormat
    
    PHImageManager.default().requestAVAsset(
        forVideo: asset,
        options: options
    ) { avAsset, _, info in
        guard let avAsset = avAsset else {
            let error = info?[PHImageErrorKey] as? Error
            completion(nil, error)
            return
        }
        
        // Export to temporary URL for processing
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mov")
        
        guard let exportSession = AVAssetExportSession(
            asset: avAsset,
            presetName: AVAssetExportPresetPassthrough
        ) else {
            completion(nil, NSError(domain: "VideoExport", code: -1))
            return
        }
        
        exportSession.outputURL = tempURL
        exportSession.outputFileType = .mov
        
        exportSession.exportAsynchronously {
            DispatchQueue.main.async {
                switch exportSession.status {
                case .completed:
                    completion(tempURL, nil)
                case .failed, .cancelled:
                    completion(nil, exportSession.error)
                default:
                    completion(nil, NSError(domain: "VideoExport", code: -2))
                }
            }
        }
    }
}
```

### Saving Compressed Video Back to Library

```swift
func saveCompressedVideo(
    fromURL videoURL: URL,
    originalAsset: PHAsset,
    completion: @escaping (Bool, Error?) -> Void
) {
    PHPhotoLibrary.shared().performChanges({
        let creationRequest = PHAssetCreationRequest.forAsset()
        creationRequest.addResource(with: .video, fileURL: videoURL, options: nil)
        
        // Copy metadata from original asset
        creationRequest.creationDate = originalAsset.creationDate
        creationRequest.location = originalAsset.location
        creationRequest.isFavorite = originalAsset.isFavorite
        
    }) { success, error in
        DispatchQueue.main.async {
            completion(success, error)
        }
    }
}
```

### Deleting Original After Compression

```swift
func replaceVideoWithCompressed(
    originalAsset: PHAsset,
    compressedVideoURL: URL,
    completion: @escaping (Bool, Error?) -> Void
) {
    PHPhotoLibrary.shared().performChanges({
        // Save compressed version
        let creationRequest = PHAssetCreationRequest.forAsset()
        creationRequest.addResource(with: .video, fileURL: compressedVideoURL, options: nil)
        creationRequest.creationDate = originalAsset.creationDate
        creationRequest.location = originalAsset.location
        creationRequest.isFavorite = originalAsset.isFavorite
        
        // Delete original
        PHAssetChangeRequest.deleteAssets([originalAsset] as NSArray)
        
    }) { success, error in
        DispatchQueue.main.async {
            completion(success, error)
        }
    }
}
```

---

## Complete Examples

### Complete Video Scanner with Size Filtering

```swift
class VideoScanner {
    struct VideoInfo {
        let asset: PHAsset
        let fileSize: Int64
        let duration: TimeInterval
        let dimensions: CGSize
        let isInCloud: Bool
        let originalFilename: String?
    }
    
    func scanVideosLargerThan(
        sizeMB: Int,
        progressHandler: @escaping (Int, Int) -> Void,
        completion: @escaping ([VideoInfo]) -> Void
    ) {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        let allVideos = PHAsset.fetchAssets(with: .video, options: fetchOptions)
        let totalCount = allVideos.count
        var processedCount = 0
        var largeVideos: [VideoInfo] = []
        
        let dispatchGroup = DispatchGroup()
        
        allVideos.enumerateObjects { asset, _, _ in
            dispatchGroup.enter()
            
            self.getVideoInfo(for: asset) { videoInfo in
                processedCount += 1
                
                if let videoInfo = videoInfo {
                    let sizeMBValue = videoInfo.fileSize / (1024 * 1024)
                    if sizeMBValue >= sizeMB {
                        largeVideos.append(videoInfo)
                    }
                }
                
                DispatchQueue.main.async {
                    progressHandler(processedCount, totalCount)
                }
                
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            completion(largeVideos)
        }
    }
    
    private func getVideoInfo(
        for asset: PHAsset,
        completion: @escaping (VideoInfo?) -> Void
    ) {
        let resources = PHAssetResource.assetResources(for: asset)
        
        guard let resource = resources.first(where: { $0.type == .video || $0.type == .fullSizeVideo }) else {
            completion(nil)
            return
        }
        
        let fileSize = resource.value(forKey: "fileSize") as? Int64 ?? 0
        let isInCloud = resource.value(forKey: "locallyAvailable") as? Bool == false
        
        let videoInfo = VideoInfo(
            asset: asset,
            fileSize: fileSize,
            duration: asset.duration,
            dimensions: CGSize(width: asset.pixelWidth, height: asset.pixelHeight),
            isInCloud: isInCloud,
            originalFilename: resource.originalFilename
        )
        
        completion(videoInfo)
    }
}
```

### Complete Video Compression Pipeline

```swift
class VideoCompressionPipeline {
    enum CompressionQuality {
        case low
        case medium
        case high
        
        var preset: String {
            switch self {
            case .low: return AVAssetExportPresetLowQuality
            case .medium: return AVAssetExportPresetMediumQuality
            case .high: return AVAssetExportPresetHighestQuality
            }
        }
    }
    
    func compressVideo(
        asset: PHAsset,
        quality: CompressionQuality,
        downloadProgressHandler: @escaping (Double) -> Void,
        compressionProgressHandler: @escaping (Float) -> Void,
        completion: @escaping (Result<Int64, Error>) -> Void
    ) {
        // Step 1: Download from iCloud if needed
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat
        
        options.progressHandler = { progress, error, stop, info in
            DispatchQueue.main.async {
                downloadProgressHandler(progress)
            }
        }
        
        PHImageManager.default().requestAVAsset(
            forVideo: asset,
            options: options
        ) { [weak self] avAsset, _, info in
            guard let avAsset = avAsset else {
                let error = info?[PHImageErrorKey] as? Error ?? NSError(domain: "Compression", code: -1)
                completion(.failure(error))
                return
            }
            
            // Step 2: Compress the video
            self?.compressAVAsset(
                avAsset,
                quality: quality,
                progressHandler: compressionProgressHandler
            ) { result in
                switch result {
                case .success(let compressedURL):
                    // Step 3: Calculate space saved
                    self?.calculateSpaceSaved(
                        originalAsset: asset,
                        compressedURL: compressedURL
                    ) { spaceSaved in
                        // Step 4: Replace original with compressed
                        self?.replaceOriginalVideo(
                            asset: asset,
                            compressedURL: compressedURL
                        ) { success in
                            if success {
                                completion(.success(spaceSaved))
                            } else {
                                completion(.failure(NSError(domain: "Compression", code: -2)))
                            }
                        }
                    }
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }
    
    private func compressAVAsset(
        _ asset: AVAsset,
        quality: CompressionQuality,
        progressHandler: @escaping (Float) -> Void,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mov")
        
        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: quality.preset
        ) else {
            completion(.failure(NSError(domain: "Compression", code: -3)))
            return
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mov
        
        // Monitor progress
        let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            DispatchQueue.main.async {
                progressHandler(exportSession.progress)
            }
        }
        
        exportSession.exportAsynchronously {
            timer.invalidate()
            
            DispatchQueue.main.async {
                switch exportSession.status {
                case .completed:
                    completion(.success(outputURL))
                case .failed:
                    completion(.failure(exportSession.error ?? NSError(domain: "Compression", code: -4)))
                case .cancelled:
                    completion(.failure(NSError(domain: "Compression", code: -5)))
                default:
                    completion(.failure(NSError(domain: "Compression", code: -6)))
                }
            }
        }
    }
    
    private func calculateSpaceSaved(
        originalAsset: PHAsset,
        compressedURL: URL,
        completion: @escaping (Int64) -> Void
    ) {
        let resources = PHAssetResource.assetResources(for: originalAsset)
        let originalSize = resources.first?.value(forKey: "fileSize") as? Int64 ?? 0
        
        do {
            let compressedSize = try compressedURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            let spaceSaved = originalSize - Int64(compressedSize)
            completion(max(spaceSaved, 0))
        } catch {
            completion(0)
        }
    }
    
    private func replaceOriginalVideo(
        asset: PHAsset,
        compressedURL: URL,
        completion: @escaping (Bool) -> Void
    ) {
        PHPhotoLibrary.shared().performChanges({
            let creationRequest = PHAssetCreationRequest.forAsset()
            creationRequest.addResource(with: .video, fileURL: compressedURL, options: nil)
            creationRequest.creationDate = asset.creationDate
            creationRequest.location = asset.location
            creationRequest.isFavorite = asset.isFavorite
            
            PHAssetChangeRequest.deleteAssets([asset] as NSArray)
        }) { success, _ in
            DispatchQueue.main.async {
                completion(success)
            }
        }
    }
}
```

---

## Official Apple Resources

### Documentation
- [PhotoKit Framework](https://developer.apple.com/documentation/photos)
- [PHPhotoLibrary](https://developer.apple.com/documentation/photos/phphotolibrary)
- [PHAsset](https://developer.apple.com/documentation/photos/phasset)
- [PHAssetResource](https://developer.apple.com/documentation/photos/phassetresource)
- [PHImageManager](https://developer.apple.com/documentation/photos/phimagemanager)
- [PHAssetResourceManager](https://developer.apple.com/documentation/photos/phassetresourcemanager)
- [AVFoundation Programming Guide](https://developer.apple.com/library/archive/documentation/AudioVideo/Conceptual/AVFoundationPG/)

### WWDC Videos
- [Improve access to Photos in your app (WWDC21)](https://developer.apple.com/videos/play/wwdc2021/10046/)
- [Discover PhotoKit change history (WWDC22)](https://developer.apple.com/videos/play/wwdc2022/10132/)
- [Create a more responsive media app (WWDC22)](https://developer.apple.com/videos/play/wwdc2022/110379/)
- [What's new in the Photos picker (WWDC22)](https://developer.apple.com/videos/play/wwdc2022/10023/)

### Key API References
```swift
// Fetch videos
PHAsset.fetchAssets(with: .video, options: PHFetchOptions)

// Get asset resources
PHAssetResource.assetResources(for: PHAsset)

// Request video data
PHImageManager.default().requestAVAsset(forVideo:options:resultHandler:)

// Request resource data
PHAssetResourceManager.default().requestData(for:options:dataReceivedHandler:completionHandler:)

// Save to library
PHPhotoLibrary.shared().performChanges(_:completionHandler:)

// Delete assets
PHAssetChangeRequest.deleteAssets(_:)
```

### Important Info.plist Keys
```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>We need access to compress your large videos and save space</string>

<key>NSPhotoLibraryAddUsageDescription</key>
<string>We need to save compressed videos back to your library</string>
```

### Common Pitfalls
1. **File size from PHAssetResource**: Uses KVO on "fileSize" key - not officially documented but widely used
2. **iCloud assets**: Always set `isNetworkAccessAllowed = true` and handle progress
3. **Resource types**: Prefer `.fullSizeVideo` over `.video` when available
4. **Memory management**: Large videos can consume significant memory - use resource managers carefully
5. **Background processing**: Video compression should be done with proper background task handling
6. **Permission handling**: Check authorization status before accessing library

---

## Best Practices for Video Compression Apps

1. **Scan efficiently**: Use PHAssetResource for quick file size estimates
2. **Prioritize large files**: Sort by file size to show biggest space savers first
3. **Handle iCloud gracefully**: Show download progress and allow cancellation
4. **Preserve metadata**: Keep creation date, location, favorites when replacing videos
5. **Allow preview**: Let users preview before/after compression
6. **Batch operations**: Process multiple videos with proper progress tracking
7. **Error handling**: Gracefully handle network errors, permission changes, storage limits
8. **Background processing**: Use background tasks for long compression operations
9. **Memory management**: Process videos one at a time to avoid memory issues
10. **Testing**: Test with various video formats, sizes, and iCloud states

---

Generated for SpaceSwap video compression app development.
