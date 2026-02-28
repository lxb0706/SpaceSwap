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
    func update(record: CompressionRecord) async throws
    var totalSavedSpace: Int64 { get async throws }
}

enum PersistenceContainerIssue: LocalizedError {
    case resetPersistentStore(underlying: Error)
    case fellBackToInMemoryStore(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .resetPersistentStore:
            return "History database was reset."
        case .fellBackToInMemoryStore:
            return "History database failed to load."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .resetPersistentStore:
            return "Your compression history may have been cleared. This can happen after an app update."
        case .fellBackToInMemoryStore:
            return "Compression history will not be saved until the next successful app launch."
        }
    }
}

final class PersistenceService: PersistenceServiceProtocol {
    static private(set) var sharedModelContainerIssue: PersistenceContainerIssue?

    static let sharedModelContainer: ModelContainer = {
        let schema = Schema([CompressionRecord.self])
        let primaryStoreName = "SpaceSwap"
        let recoveryStoreName = "SpaceSwap-Recovery"
        let useRecoveryStoreKey = "PersistenceService.useRecoveryStore"
        let didReportRecoveryKey = "PersistenceService.didReportRecovery"

        if UserDefaults.standard.bool(forKey: useRecoveryStoreKey) {
            do {
                let configuration = makePersistentConfiguration(schema: schema, storeName: recoveryStoreName)
                return try ModelContainer(for: schema, configurations: [configuration])
            } catch {
                sharedModelContainerIssue = .fellBackToInMemoryStore(underlying: error)
                do {
                    let memoryConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                    return try ModelContainer(for: schema, configurations: [memoryConfiguration])
                } catch {
                    fatalError("Failed to create SwiftData ModelContainer: \(error)")
                }
            }
        }

        do {
            let configuration = makePersistentConfiguration(schema: schema, storeName: primaryStoreName)
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            let underlyingError = error
            do {
                UserDefaults.standard.set(true, forKey: useRecoveryStoreKey)
                if !UserDefaults.standard.bool(forKey: didReportRecoveryKey) {
                    sharedModelContainerIssue = .resetPersistentStore(underlying: underlyingError)
                    UserDefaults.standard.set(true, forKey: didReportRecoveryKey)
                }

                let configuration = makePersistentConfiguration(schema: schema, storeName: recoveryStoreName)
                return try ModelContainer(for: schema, configurations: [configuration])
            } catch {
                sharedModelContainerIssue = .fellBackToInMemoryStore(underlying: underlyingError)
                do {
                    let memoryConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                    return try ModelContainer(for: schema, configurations: [memoryConfiguration])
                } catch {
                    fatalError("Failed to create SwiftData ModelContainer: \(error)")
                }
            }
        }
    }()

    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    convenience init() {
        let modelContext = ModelContext(Self.sharedModelContainer)
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

    func update(record: CompressionRecord) async throws {
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

private extension PersistenceService {
    static func makePersistentConfiguration(schema: Schema, storeName: String) -> ModelConfiguration {
        ModelConfiguration(storeName, schema: schema, isStoredInMemoryOnly: false)
    }
}
