//
//  CompressionRecord.swift
//  SpaceSwap
//
//  Created by 连晓彬 on 2026/2/9.
//

import Foundation
import SwiftData

@Model
final class CompressionRecord {
    var id: UUID
    var originalAssetID: String
    var compressedAssetID: String
    var originalFilename: String
    var date: Date
    var originalSize: Int64
    var compressedSize: Int64
    var compressionRatio: Double
    var quality: String
    var status: Int
    var isAssetDeleted: Bool
    
    init(
        originalAssetID: String,
        compressedAssetID: String,
        originalFilename: String = "",
        date: Date,
        originalSize: Int64,
        compressedSize: Int64,
        compressionRatio: Double,
        quality: String,
        status: Int,
        isAssetDeleted: Bool
    ) {
        self.id = UUID()
        self.originalAssetID = originalAssetID
        self.compressedAssetID = compressedAssetID
        self.originalFilename = originalFilename
        self.date = date
        self.originalSize = originalSize
        self.compressedSize = compressedSize
        self.compressionRatio = compressionRatio
        self.quality = quality
        self.status = status
        self.isAssetDeleted = isAssetDeleted
    }
}
