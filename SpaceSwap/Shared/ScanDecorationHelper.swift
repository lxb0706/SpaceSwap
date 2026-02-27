//
//  ScanDecorationHelper.swift
//  SpaceSwap
//
//  Created by 连晓彬 on 2026/2/27.
//

import Foundation

enum ScanDecorationHelper {
    static func decorate(
        scannedIDs: [String],
        originalIDs: Set<String>,
        compressedIDs: Set<String>
    ) -> (filteredIDs: [String], compressedCopyIDs: Set<String>) {
        let filtered = scannedIDs.filter { !originalIDs.contains($0) }
        let compressedCopyIDs = Set(filtered).intersection(compressedIDs)
        return (filteredIDs: filtered, compressedCopyIDs: compressedCopyIDs)
    }
}

