//
//  PersistenceService.swift
//  SpaceSwap
//
//  Created by 连晓彬 on 2026/2/9.
//

import SwiftData
import Combine

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
    
    func save(record: CompressionRecord) async throws {
        modelContext.insert(record)
        try modelContext.save()
    }
    
    func fetchAll() async throws -> [CompressionRecord] {
        let descriptor = FetchDescriptor<CompressionRecord>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        return try modelContext.fetch(descriptor)
    }
    
    func delete(record: CompressionRecord) async throws {
        modelContext.delete(record)
        try modelContext.save()
    }
    
    var totalSavedSpace: Int64 {
        get async throws {
            let descriptor = FetchDescriptor<CompressionRecord>(
                predicate: #Predicate { $0.status == 1 }
            )
            let records = try modelContext.fetch(descriptor)
            return records.reduce(0) { $0 + ($1.originalSize - $1.compressedSize) }
        }
    }
}