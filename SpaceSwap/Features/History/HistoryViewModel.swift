//
//  HistoryViewModel.swift
//  SpaceSwap
//
//  Created by 连晓彬 on 2026/2/9.
//

import SwiftUI
import Combine

@MainActor
final class HistoryViewModel: ObservableObject {
    @Published var compressionRecords: [CompressionRecord] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private let persistenceService: PersistenceServiceProtocol
    
    init(persistenceService: PersistenceServiceProtocol = PersistenceService()) {
        self.persistenceService = persistenceService
        loadHistory()
    }
    
    func loadHistory() {
        isLoading = true
        error = nil
        
        Task {
            do {
                let records = try await persistenceService.fetchAll()
                compressionRecords = records
            } catch {
                self.error = error
            }
            isLoading = false
        }
    }
    
    func deleteRecord(_ record: CompressionRecord) {
        Task {
            do {
                try await persistenceService.delete(record: record)
                loadHistory() // Reload after deletion
            } catch {
                self.error = error
            }
        }
    }
    
    func clearAllHistory() {
        Task {
            do {
                let allRecords = try await persistenceService.fetchAll()
                for record in allRecords {
                    try await persistenceService.delete(record: record)
                }
                loadHistory() // Reload after clearing
            } catch {
                self.error = error
            }
        }
    }
    
    var totalSpaceSaved: Int64 {
        compressionRecords
            .filter { $0.status == 1 } // Only successful compressions
            .reduce(0) { $0 + ($1.originalSize - $1.compressedSize) }
    }
    
    var totalCompressionCount: Int {
        compressionRecords.filter { $0.status == 1 }.count
    }
}