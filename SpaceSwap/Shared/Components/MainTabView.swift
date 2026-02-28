//
//  MainTabView.swift
//  SpaceSwap
//
//  Created by 连晓彬 on 2026/2/9.
//

import SwiftUI

struct MainTabView: View {
    @State private var showPersistenceAlert = false
    @State private var persistenceIssueMessage = ""

    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house")
                }
            
            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock")
                }
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        .onAppear {
            guard !showPersistenceAlert else { return }
            guard let issue = PersistenceService.sharedModelContainerIssue else { return }

            persistenceIssueMessage = issue.recoverySuggestion ?? issue.localizedDescription
            showPersistenceAlert = true
        }
        .alert("Storage", isPresented: $showPersistenceAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(persistenceIssueMessage)
        }
    }
}
