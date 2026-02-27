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

    func testBaseNameStripsExtension() throws {
        XCTAssertEqual("IMG_0001.MOV".spaceswapBaseName, "IMG_0001")
        XCTAssertEqual("noext".spaceswapBaseName, "noext")
        XCTAssertEqual("a.b.c.mov".spaceswapBaseName, "a.b.c")
    }

    func testCompressedCopyDisplayNameUsesSSSuffix() throws {
        XCTAssertEqual(
            "IMG_0001_SS_1",
            String.spaceswapCompressedCopyDisplayName(originalFilename: "IMG_0001.MOV", sequence: 1)
        )
    }

    func testHistoryDeleteOriginalUpdatesPersistenceAndReloads() async throws {
        final class PhotoLibraryServiceMock: PhotoLibraryServiceProtocol {
            var deletedIdentifiers: [String] = []
            var onDelete: (() -> Void)?

            func fetchLargeVideos(minSize: Int64) async throws -> [PhotoAsset] {
                []
            }

            func deleteAsset(_ asset: PhotoAsset) async throws {
            }

            func deleteAsset(localIdentifier: String) async throws {
                deletedIdentifiers.append(localIdentifier)
                onDelete?()
            }

            func saveVideo(from url: URL) async throws -> String {
                ""
            }

            func compressVideo(
                _ asset: PhotoAsset,
                quality: CompressionQuality,
                progressHandler: @escaping (Double) -> Void
            ) async throws -> CompressionResult {
                CompressionResult(compressedAssetId: "", compressedSize: 0)
            }
        }

        final class PersistenceServiceMock: PersistenceServiceProtocol {
            var records: [CompressionRecord] = []
            var updateCallCount = 0
            var onUpdate: (() -> Void)?
            var onFetchAll: (() -> Void)?

            func save(record: CompressionRecord) async throws {
            }

            func fetchAll() async throws -> [CompressionRecord] {
                onFetchAll?()
                return records
            }

            func delete(record: CompressionRecord) async throws {
            }

            func update(record: CompressionRecord) async throws {
                updateCallCount += 1
                onUpdate?()
            }

            var totalSavedSpace: Int64 {
                get async throws { 0 }
            }
        }

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

        let deleteCalled = expectation(description: "Photo library delete called")
        let updateCalled = expectation(description: "Persistence update called")
        let fetchAllCalled = expectation(description: "History reloaded")
        fetchAllCalled.expectedFulfillmentCount = 2

        let photoLibraryService = PhotoLibraryServiceMock()
        photoLibraryService.onDelete = { deleteCalled.fulfill() }

        let persistenceService = PersistenceServiceMock()
        persistenceService.records = [record]
        persistenceService.onUpdate = { updateCalled.fulfill() }
        persistenceService.onFetchAll = { fetchAllCalled.fulfill() }

        let viewModel = await MainActor.run {
            HistoryViewModel(
                persistenceService: persistenceService,
                photoLibraryService: photoLibraryService,
                shouldLoadHistory: true
            )
        }

        await MainActor.run {
            viewModel.deleteOriginal(for: record)
        }

        await fulfillment(of: [deleteCalled, updateCalled, fetchAllCalled], timeout: 3.0)

        XCTAssertEqual(photoLibraryService.deletedIdentifiers, ["orig"])
        XCTAssertEqual(persistenceService.updateCallCount, 1)
        XCTAssertTrue(record.isAssetDeleted)
    }
}
