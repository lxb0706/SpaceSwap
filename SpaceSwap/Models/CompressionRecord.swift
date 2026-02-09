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
    var date: Date
    var originalSize: Int64
    var compressedSize: Int64
    var status: Int
    var isAssetDeleted: Bool
    
    init(
        originalAssetID: String,
        date: Date,
        originalSize: Int64,
        compressedSize: Int64,
        status: Int,
        isAssetDeleted: Bool
    ) {
        self.id = UUID()
        self.originalAssetID = originalAssetID
        self.date = date
        self.originalSize = originalSize
        self.compressedSize = compressedSize
        self.status = status
        self.isAssetDeleted = isAssetDeleted
    }
}