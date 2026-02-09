//
//  Int64+Formatting.swift
//  SpaceSwap
//
//  Created by 连晓彬 on 2026/2/9.
//

import Foundation

extension Int64 {
    var formattedBytes: String {
        let bytes = Double(self)
        let units = ["B", "KB", "MB", "GB", "TB"]
        var value = bytes
        var unitIndex = 0
        
        while value >= 1024 && unitIndex < units.count - 1 {
            value /= 1024
            unitIndex += 1
        }
        
        return String(format: "%.1f %@", value, units[unitIndex])
    }
}