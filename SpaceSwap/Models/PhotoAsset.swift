//
//  PhotoAsset.swift
//  SpaceSwap
//
//  Created by 连晓彬 on 2026/2/9.
//

import Photos
import UIKit

struct PhotoAsset: Identifiable, Hashable {
    let id: String
    let phAsset: PHAsset
    let filename: String
    let fileSize: Int64
    let duration: TimeInterval
    let isCloudAsset: Bool
    let creationDate: Date?
    let locationText: String?
    let latitude: Double?
    let longitude: Double?
    
    init(phAsset: PHAsset, fileSize: Int64) {
        let primaryResource = PHAssetResource.assetResources(for: phAsset).first
        let locallyAvailable = primaryResource?.value(forKey: "locallyAvailable") as? Bool
        self.id = phAsset.localIdentifier
        self.phAsset = phAsset
        self.filename = primaryResource?.originalFilename ?? "Unknown Video"
        self.fileSize = fileSize
        self.duration = phAsset.duration
        self.isCloudAsset = (locallyAvailable == false)
        self.creationDate = phAsset.creationDate
        if let location = phAsset.location {
            self.latitude = location.coordinate.latitude
            self.longitude = location.coordinate.longitude
            self.locationText = String(
                format: "%.4f, %.4f",
                location.coordinate.latitude,
                location.coordinate.longitude
            )
        } else {
            self.latitude = nil
            self.longitude = nil
            self.locationText = nil
        }
    }
    
    func thumbnail(size: CGSize = CGSize(width: 100, height: 100)) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.resizeMode = .exact
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false
            
            PHImageManager.default().requestImage(
                for: phAsset,
                targetSize: size,
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }
    
    static func == (lhs: PhotoAsset, rhs: PhotoAsset) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
