//
//  CompressionRecordFactory.swift
//  SpaceSwap
//
//  Created by 连晓彬 on 2026/2/27.
//

import Foundation

enum CompressionRecordFactory {
    static func make(
        originalAssetID: String,
        compressedAssetID: String,
        originalFilename: String,
        date: Date = Date(),
        originalSize: Int64,
        compressedSize: Int64,
        quality: String,
        status: Int,
        isAssetDeleted: Bool
    ) -> CompressionRecord {
        let compressionRatio: Double
        if originalSize > 0 {
            compressionRatio = Double(compressedSize) / Double(originalSize)
        } else {
            compressionRatio = 0.0
        }

        return CompressionRecord(
            originalAssetID: originalAssetID,
            compressedAssetID: compressedAssetID,
            originalFilename: originalFilename,
            date: date,
            originalSize: originalSize,
            compressedSize: compressedSize,
            compressionRatio: compressionRatio,
            quality: quality,
            status: status,
            isAssetDeleted: isAssetDeleted
        )
    }
}

