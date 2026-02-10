//
//  PersistenceService.swift
//  SpaceSwap
//
//  Created by 连晓彬 on 2026/2/9.
//

import SwiftData
import Combine
import Foundation

protocol PersistenceServiceProtocol {
    func save(record: CompressionRecord) async throws
    func fetchAll() async throws -> [CompressionRecord]
    func delete(record: CompressionRecord) async throws
    var totalSavedSpace: Int64 { get async throws }
}

final class PersistenceService: PersistenceServiceProtocol {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    convenience init() {
        let schema = Schema([CompressionRecord.self])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        let modelContainer = try! ModelContainer(for: schema, configurations: [modelConfiguration])
        let modelContext = ModelContext(modelContainer)
        self.init(modelContext: modelContext)
    }
    
    func save(record: CompressionRecord) async throws {
        modelContext.insert(record)
        try modelContext.save()
    }
    
    func fetchAll() async throws -> [CompressionRecord] {
        let descriptor = FetchDescriptor<CompressionRecord>()
        let records = try modelContext.fetch(descriptor)
        return records.sorted { $0.date > $1.date }
    }
    
    func delete(record: CompressionRecord) async throws {
        modelContext.delete(record)
        try modelContext.save()
    }
    
    var totalSavedSpace: Int64 {
        get async throws {
            let descriptor = FetchDescriptor<CompressionRecord>()
            let records = try modelContext.fetch(descriptor)
            let successfulRecords = records.filter { $0.status == 1 }
            return successfulRecords.reduce(0) { $0 + ($1.originalSize - $1.compressedSize) }
        }
    }
}