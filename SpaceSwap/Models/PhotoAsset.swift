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
    let fileSize: Int64
    let duration: TimeInterval
    let isCloudAsset: Bool
    
    init(phAsset: PHAsset, fileSize: Int64) {
        self.id = phAsset.localIdentifier
        self.phAsset = phAsset
        self.fileSize = fileSize
        self.duration = phAsset.duration
        self.isCloudAsset = phAsset.sourceType == .typeCloudShared
    }
    
    func thumbnail(size: CGSize = CGSize(width: 100, height: 100)) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .fastFormat
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