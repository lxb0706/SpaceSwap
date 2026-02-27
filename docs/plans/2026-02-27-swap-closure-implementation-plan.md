# Swap Closure (Manual Delete + Scan De-dupe) Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Complete the MVP “Swap” loop by letting users delete originals from History (with confirmation), and ensure future scans hide already-compressed originals while clearly labeling compressed copies with an `*_SS_1` display name.

**Architecture:** Keep MVVM and protocol-based services. Persist compression results in SwiftData (`CompressionRecord`). Use SwiftData records to (1) drive History “Delete Original” behavior and (2) post-process scan results for de-dupe + “Compressed Copy” UI decoration. File naming is an in-app display name only (PhotoKit does not reliably allow renaming assets).

**Tech Stack:** SwiftUI, SwiftData, Photos/PhotoKit, AVFoundation, Combine, XCTest

---

### Task 1: Add `originalFilename` to compression history records

**Files:**
- Modify: `SpaceSwap/Models/CompressionRecord.swift:12`

**Step 1: Write the failing test**

Modify `SpaceSwapTests/SpaceSwapTests.swift` to assert the model initializer accepts `originalFilename` and stores it.

```swift
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
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild -scheme SpaceSwap -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' test -only-testing:SpaceSwapTests`

Expected: FAIL due to missing `originalFilename` property/initializer parameter.

**Step 3: Write minimal implementation**

Update `CompressionRecord`:
- Add `var originalFilename: String`
- Add `originalFilename` to initializer signature and assignment

**Step 4: Run tests to verify it passes**

Run: `xcodebuild -scheme SpaceSwap -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' test -only-testing:SpaceSwapTests`

Expected: PASS

**Step 5: Commit**

```bash
git add SpaceSwap/Models/CompressionRecord.swift SpaceSwapTests/SpaceSwapTests.swift
git commit -m "[feature] CompressionRecord 保存原始文件名"
```

---

### Task 2: Write `originalFilename` when creating `CompressionRecord`

**Files:**
- Modify: `SpaceSwap/Services/CompressionQueueManager.swift:171`
- Modify: `SpaceSwap/Features/Compression/CompressionViewModel.swift:41`

**Step 1: Write the failing test**

Add a unit test for the naming helper (Task 4) first, then in this task add a lightweight “record creation” test by extracting record-building into a pure function.

Create a new helper (internal) in `SpaceSwap/Shared/` that builds a record from inputs; test it without PhotoKit.

**Step 2: Run test to verify it fails**

Run: `xcodebuild ... test -only-testing:SpaceSwapTests`

Expected: FAIL because helper does not exist or `originalFilename` not threaded through.

**Step 3: Write minimal implementation**

- In `CompressionQueueManager.executeCompression` record creation, pass `originalFilename: entry.asset.filename`
- In `CompressionViewModel.startCompression` record creation, pass `originalFilename: asset.filename`

If you created a record factory helper, use it from both call sites to avoid drift.

**Step 4: Run tests**

Run: `xcodebuild ... test -only-testing:SpaceSwapTests`

Expected: PASS

**Step 5: Commit**

```bash
git add SpaceSwap/Services/CompressionQueueManager.swift SpaceSwap/Features/Compression/CompressionViewModel.swift SpaceSwapTests/SpaceSwapTests.swift
git commit -m "[feature] 压缩历史写入 originalFilename"
```

---

### Task 3: Add persistence update API for toggling `isAssetDeleted`

**Files:**
- Modify: `SpaceSwap/Services/PersistenceService.swift:12`

**Step 1: Write the failing test**

Add a unit test that calls the new `update(record:)` API on an in-memory SwiftData container.

Implementation approach for test:
- Create a local `ModelContainer` with `isStoredInMemoryOnly: true`
- Create `ModelContext` from it
- Instantiate `PersistenceService(modelContext:)`
- Insert a record, mutate `isAssetDeleted`, call `update(record:)`, refetch, assert persisted.

**Step 2: Run test to verify it fails**

Expected: FAIL because `update(record:)` does not exist.

**Step 3: Write minimal implementation**

In `PersistenceServiceProtocol` add:
- `func update(record: CompressionRecord) async throws`

In `PersistenceService` implement:
- `try modelContext.save()` (SwiftData tracks changes; no re-insert needed)

**Step 4: Run tests**

Expected: PASS

**Step 5: Commit**

```bash
git add SpaceSwap/Services/PersistenceService.swift SpaceSwapTests/SpaceSwapTests.swift
git commit -m "[feature] PersistenceService 支持更新记录"
```

---

### Task 4: Add display-name helper for `*_SS_1` (base name strips extension)

**Files:**
- Create: `SpaceSwap/Shared/Extensions/String+Filename.swift`
- Test: `SpaceSwapTests/SpaceSwapTests.swift`

**Step 1: Write the failing test**

```swift
func testBaseNameStripsExtension() throws {
    XCTAssertEqual("IMG_0001.MOV".spaceswapBaseName, "IMG_0001")
    XCTAssertEqual("noext".spaceswapBaseName, "noext")
    XCTAssertEqual("a.b.c.mov".spaceswapBaseName, "a.b.c")
}

func testCompressedCopyDisplayNameUsesSSSuffix() throws {
    XCTAssertEqual("IMG_0001_SS_1", String.spaceswapCompressedCopyDisplayName(originalFilename: "IMG_0001.MOV", sequence: 1))
}
```

**Step 2: Run test to verify it fails**

Expected: FAIL because helpers are missing.

**Step 3: Write minimal implementation**

Implement:
- `var spaceswapBaseName: String` as a computed property on `String`
- `static func spaceswapCompressedCopyDisplayName(originalFilename: String, sequence: Int) -> String`

**Step 4: Run tests**

Expected: PASS

**Step 5: Commit**

```bash
git add SpaceSwap/Shared/Extensions/String+Filename.swift SpaceSwapTests/SpaceSwapTests.swift
git commit -m "[feature] 压缩副本显示名工具函数"
```

---

### Task 5: Add PhotoKit delete-by-localIdentifier API

**Files:**
- Modify: `SpaceSwap/Services/PhotoLibraryService.swift:50`

**Step 1: Write the failing test**

Skip unit test (PhotoKit not test-friendly in unit tests). Use careful implementation + manual simulator validation.

**Step 2: Implement**

In `PhotoLibraryServiceProtocol` add:
- `func deleteAsset(localIdentifier: String) async throws`

Implementation steps:
- `try await ensureAuthorization()`
- Fetch `PHAsset` via `PHAsset.fetchAssets(withLocalIdentifiers:options:)`
- If missing, throw a `PhotoLibraryError` (add new case: `assetNotFound`)
- `PHPhotoLibrary.shared().performChanges { PHAssetChangeRequest.deleteAssets([asset] as NSArray) }`

**Step 3: Build**

Run: `xcodebuild -scheme SpaceSwap -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' build`

Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add SpaceSwap/Services/PhotoLibraryService.swift
git commit -m "[feature] 支持按 localIdentifier 删除原片"
```

---

### Task 6: Implement History “Delete Original” (with confirmation) and persist `isAssetDeleted`

**Files:**
- Modify: `SpaceSwap/Features/History/HistoryViewModel.swift:12`
- Modify: `SpaceSwap/Features/History/HistoryView.swift:70`

**Step 1: Write the failing test**

Write a unit test for ViewModel state update behavior by injecting mocks:
- Mock `PhotoLibraryServiceProtocol` that records deleted identifiers
- Mock `PersistenceServiceProtocol` (or use in-memory SwiftData) that records update calls

Test expectation:
- Calling `deleteOriginal(record:)` sets `record.isAssetDeleted=true` and reloads history.

**Step 2: Run test to verify it fails**

Expected: FAIL due to missing APIs/methods.

**Step 3: Implement ViewModel**

In `HistoryViewModel`:
- Inject `photoLibraryService: PhotoLibraryServiceProtocol`
- Add `func deleteOriginal(for record: CompressionRecord) { ... }`
  - `try await photoLibraryService.deleteAsset(localIdentifier: record.originalAssetID)`
  - `record.isAssetDeleted = true`
  - `try await persistenceService.update(record: record)`
  - `loadHistory()`
  - On error, set `self.error`

**Step 4: Implement View UI**

In `HistoryView`:
- Add `@State private var recordPendingDeleteOriginal: CompressionRecord?`
- Render per-record button:
  - If `record.status==1 && !record.isAssetDeleted` show `Button("Delete Original")` (role: `.destructive`)
  - Else show `Text("Original Deleted")` style
- Add `.alert` confirmation bound to `recordPendingDeleteOriginal`
  - Confirm triggers `viewModel.deleteOriginal(for: record)`

**Step 5: Run tests + build**

Run: `xcodebuild ... test -only-testing:SpaceSwapTests`
Run: `xcodebuild ... build`

Expected: PASS + BUILD SUCCEEDED

**Step 6: Commit**

```bash
git add SpaceSwap/Features/History/HistoryView.swift SpaceSwap/Features/History/HistoryViewModel.swift SpaceSwapTests/SpaceSwapTests.swift
git commit -m "[feature] History 支持手动删除原片并回写状态"
```

---

### Task 7: De-dupe scan results + label compressed copies in Home list

**Files:**
- Modify: `SpaceSwap/Features/Home/HomeViewModel.swift:12`
- Modify: `SpaceSwap/Features/Home/HomeView.swift:513`

**Step 1: Write the failing test**

Add a pure function (testable) for scan decoration:
- Input: `[String] scannedIDs`, `Set<String> originalIDs`, `Set<String> compressedIDs`
- Output:
  - `filteredIDs` (originalIDs removed)
  - `compressedCopyIDs` (intersection with compressedIDs)

Test it in `SpaceSwapTests`.

**Step 2: Run test to verify it fails**

Expected: FAIL because helper doesn’t exist.

**Step 3: Implement HomeViewModel changes**

- Inject `persistenceService: PersistenceServiceProtocol`
- In `startScan()` after fetching assets:
  - Fetch all records (or only Success) from persistence
  - Build:
    - `successOriginalIDs: Set<String>`
    - `successCompressedIDToRecord: [String: CompressionRecord]`
  - Filter assets:
    - Remove any asset where `asset.id` in `successOriginalIDs`
  - Store additional decorations:
    - `@Published var compressedCopyRecordsByAssetID: [String: CompressionRecord]`

**Step 4: Implement Home list UI changes**

Update `AssetRowView` signature:
- Add `displayName: String`
- Add `isCompressedCopy: Bool`

Display:
- Use `displayName` instead of `asset.filename`
- If `isCompressedCopy` show a `Compressed Copy` capsule/badge

Compute in `HomeView`:
- `let record = viewModel.compressedCopyRecordsByAssetID[asset.id]`
- `displayName = record != nil ? String.spaceswapCompressedCopyDisplayName(originalFilename: record!.originalFilename, sequence: 1) : asset.filename`
- `isCompressedCopy = record != nil`

**Step 5: Run build**

Run: `xcodebuild -scheme SpaceSwap -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' build`

Expected: BUILD SUCCEEDED

**Step 6: Commit**

```bash
git add SpaceSwap/Features/Home/HomeViewModel.swift SpaceSwap/Features/Home/HomeView.swift SpaceSwapTests/SpaceSwapTests.swift
git commit -m "[feature] 扫描去重并标记压缩副本"
```

---

### Task 8: Replace Home “Potential savings” with SwiftData-backed total saved space

**Files:**
- Modify: `SpaceSwap/Features/Home/HomeView.swift` (the summary section showing “Potential savings”)

**Step 1: Implement**

Option A (preferred): Add a lightweight view model that queries `PersistenceService.totalSavedSpace`.

Option B: Use `@Query` inside `HomeView` for `CompressionRecord` and compute total saved (keep it simple).

**Step 2: Build**

Run: `xcodebuild -scheme SpaceSwap -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' build`

Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add SpaceSwap/Features/Home/HomeView.swift
git commit -m "[style] Home 节省空间统计改为历史口径"
```

---

### Task 9: Manual validation checklist (simulator)

**Steps:**
1. Scan a library containing at least one large video.
2. Compress one video successfully.
3. Verify:
   - History record appears, `isAssetDeleted=false`, shows “Delete Original”.
4. Tap “Delete Original”:
   - Confirmation alert appears.
   - After confirm, asset goes to “Recently Deleted”.
   - History record updates to “Original Deleted”.
5. Re-scan:
   - Original video no longer appears.
   - Compressed copy appears (if still above threshold) with “Compressed Copy” badge and `*_SS_1` display name.

---

## Execution Handoff

Plan complete and saved to `docs/plans/2026-02-27-swap-closure-implementation-plan.md`.

Two execution options:

1. Subagent-Driven (this session) — I dispatch a fresh subagent per task, review between tasks.
2. Parallel Session (separate) — Open a new session using superpowers:executing-plans.

Which approach?

