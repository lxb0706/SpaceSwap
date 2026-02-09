//
//  SpaceSwapApp.swift
//  SpaceSwap
//
//  Created by 连晓彬 on 2026/2/9.
//

import SwiftUI
import SwiftData

@main
struct SpaceSwapApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: CompressionRecord.self)
    }
}
