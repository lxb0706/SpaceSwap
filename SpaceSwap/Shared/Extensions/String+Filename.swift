//
//  String+Filename.swift
//  SpaceSwap
//
//  Created by 连晓彬 on 2026/2/27.
//

import Foundation

extension String {
    var spaceswapBaseName: String {
        (self as NSString).deletingPathExtension
    }

    static func spaceswapCompressedCopyDisplayName(originalFilename: String, sequence: Int) -> String {
        "\(originalFilename.spaceswapBaseName)_SS_\(sequence)"
    }
}

