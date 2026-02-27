//
//  SpaceSwapTests.swift
//  SpaceSwapTests
//
//  Created by 连晓彬 on 2026/2/9.
//

import XCTest
import SwiftData
@testable import SpaceSwap

final class SpaceSwapTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // Any test you write for XCTest can be annotated as throws and async.
        // Mark your test throws to produce an unexpected failure when your test encounters an uncaught error.
        // Mark your test async to allow awaiting for asynchronous code to complete. Check the results with assertions afterwards.
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

    func testCompressionRecordStoresOriginalFilename() throws {
        let record = CompressionRecord(
            originalAssetID: "orig",
            compressedAssetID: "comp",
            originalFilename: "IMG_0001.MOV",
            date: Date(),
            originalSize: 100,
            compressedSize: 50,
            compressionRatio: 0.5,
            quality: "Medium",
            status: 1,
            isAssetDeleted: false
        )
        XCTAssertEqual(record.originalFilename, "IMG_0001.MOV")
    }

    func testCompressionRecordFactoryThreadsOriginalFilename() throws {
        let record = CompressionRecordFactory.make(
            originalAssetID: "orig",
            compressedAssetID: "comp",
            originalFilename: "IMG_0001.MOV",
            date: Date(timeIntervalSince1970: 0),
            originalSize: 100,
            compressedSize: 50,
            quality: "Medium",
            status: 1,
            isAssetDeleted: false
        )
        XCTAssertEqual(record.originalFilename, "IMG_0001.MOV")
        XCTAssertEqual(record.compressionRatio, 0.5, accuracy: 0.000_001)
    }

    func testPersistenceUpdatePersistsAssetDeletedFlag() async throws {
        let schema = Schema([CompressionRecord.self])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        let modelContext = ModelContext(modelContainer)
        let persistenceService = PersistenceService(modelContext: modelContext)

        let record = CompressionRecordFactory.make(
            originalAssetID: "orig",
            compressedAssetID: "comp",
            originalFilename: "IMG_0001.MOV",
            date: Date(timeIntervalSince1970: 0),
            originalSize: 100,
            compressedSize: 50,
            quality: "Medium",
            status: 1,
            isAssetDeleted: false
        )

        try await persistenceService.save(record: record)

        record.isAssetDeleted = true
        try await persistenceService.update(record: record)

        let records = try await persistenceService.fetchAll()
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.isAssetDeleted, true)
    }
}
