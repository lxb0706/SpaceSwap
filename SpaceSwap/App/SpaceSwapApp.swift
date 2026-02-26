//
//  SpaceSwapApp.swift
//  SpaceSwap
//
//  Created by 连晓彬 on 2026/2/9.
//

import SwiftUI
import SwiftData
import AppIntents

@available(iOS 17.0, *)
struct SpaceSwapShortcutsProvider: AppShortcutsProvider {
    @AppShortcutsBuilder
    static var appShortcuts: [AppShortcut] { }
}

@main
struct SpaceSwapApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(PersistenceService.sharedModelContainer)
    }
}
