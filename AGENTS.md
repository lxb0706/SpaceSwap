# SpaceSwap – Agent Guide

## Overview
iOS 相册空间优化工具，核心功能：扫描系统相册中的大体积视频并压缩以节省存储空间。

## Stack & Layout
- **Platform**: iOS, SwiftUI, SwiftData, Xcode project
- **Scheme**: `SpaceSwap`
- **Targets**: `SpaceSwap` (app), `SpaceSwapTests` (unit), `SpaceSwapUITests` (UI)

```
SpaceSwap/
├─ App/                 # @main entry point
├─ Features/            # Feature modules (Home, Compression, History, Settings)
│  └─ {Feature}/        # View + ViewModel pairs
├─ Models/              # Data models (PhotoAsset, CompressionRecord)
├─ Services/            # Business logic (PhotoLibrary, Settings, Persistence)
├─ Shared/
│  ├─ Components/       # Reusable UI components
│  └─ Extensions/       # Swift extensions
└─ Assets.xcassets/     # App icons, colors
```

## Build & Test Commands

### Build
```bash
xcodebuild -scheme SpaceSwap \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' build
```

### Run All Tests
```bash
# Unit tests
xcodebuild -scheme SpaceSwap \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
  test -only-testing:SpaceSwapTests

# UI tests
xcodebuild -scheme SpaceSwap \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
  test -only-testing:SpaceSwapUITests
```

### Run Single Test
```bash
# Single test class
xcodebuild -scheme SpaceSwap \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
  test -only-testing:SpaceSwapTests/SpaceSwapTests

# Single test method
xcodebuild -scheme SpaceSwap \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
  test -only-testing:SpaceSwapTests/SpaceSwapTests/testExample
```

## Linting & Formatting
No SwiftLint/SwiftFormat configured. Rely on Xcode compiler diagnostics.

## Code Style

### Architecture Pattern
- **MVVM**: `View` + `ViewModel` per feature
- **Services**: Protocol-based dependency injection
- **Persistence**: SwiftData `@Model` for records

### Naming
| Element | Convention | Example |
|---------|------------|---------|
| Types | UpperCamelCase | `HomeViewModel`, `PhotoAsset` |
| Functions/Variables | lowerCamelCase | `startScan()`, `scannedAssets` |
| Protocols | Suffix with `Protocol` | `PhotoLibraryServiceProtocol` |
| Test classes | Suffix with `Tests` | `SpaceSwapTests` |
| Test methods | Prefix with `test` | `testExample` |

### Imports
```swift
import SwiftUI      // Views
import Foundation   // Non-UI code
import Photos       // Photo library access
import SwiftData    // Persistence
import Combine      // Reactive (ViewModels)
```
Group Apple frameworks first, third-party below (none yet).

### ViewModels
```swift
@MainActor
final class HomeViewModel: ObservableObject {
    @Published var isScanning = false
    private let photoLibraryService: PhotoLibraryServiceProtocol
    
    init(photoLibraryService: PhotoLibraryServiceProtocol = PhotoLibraryService()) {
        self.photoLibraryService = photoLibraryService
    }
}
```
- Mark `@MainActor` for UI-bound logic
- Use `@Published` for observable state
- Inject dependencies via protocols with defaults

### Views
```swift
public struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    
    public var body: some View { ... }
}
```
- Use `@StateObject` for owned ViewModels
- Extract subviews when complexity grows
- Prefer computed properties over duplicated state

### Services
```swift
protocol PhotoLibraryServiceProtocol {
    func fetchLargeVideos(minSize: Int64) async throws -> [PhotoAsset]
}

final class PhotoLibraryService: PhotoLibraryServiceProtocol { ... }
```
- Define protocols for all services
- Use `async throws` for fallible async operations
- Prefer `withCheckedThrowingContinuation` for callback-to-async bridges

### Models
```swift
// Value type for runtime data
struct PhotoAsset: Identifiable, Hashable {
    let id: String
    let fileSize: Int64
}

// SwiftData model for persistence
@Model
final class CompressionRecord {
    var id: UUID
    var originalSize: Int64
}
```

### Error Handling
- Use `do { try ... } catch { ... }` — never empty catch blocks
- Surface errors to UI via `@Published var error: Error?`
- Avoid `try!` and force unwraps in production code
- Use `fatalError` only for truly unrecoverable programmer errors

### Async/Await
```swift
func startScan() {
    scanTask = Task {
        do {
            let assets = try await photoLibraryService.fetchLargeVideos(minSize: minSize)
            await MainActor.run { self.scannedAssets = assets }
        } catch {
            await MainActor.run { self.error = error }
        }
    }
}
```
- Use `Task` for async work from synchronous context
- Use `Task.checkCancellation()` for cancellable operations
- Dispatch UI updates via `MainActor.run { }`

### Extensions
Place in `Shared/Extensions/` with naming: `{Type}+{Purpose}.swift`
```swift
// Int64+Formatting.swift
extension Int64 {
    var formattedBytes: String { ... }
}
```

## Git Commit Style
使用中括号标签风格：`[tag] 简要描述`

| Tag | 用途 |
|-----|------|
| `[feature]` | 新功能 |
| `[bugfix]` | 修复 bug |
| `[refactor]` | 重构 |
| `[style]` | UI/样式调整 |
| `[docs]` | 文档 |
| `[test]` | 测试 |
| `[chore]` | 杂项 |

```
[feature] 支持系统相册大体积视频压缩
[bugfix] 修复相册权限变更后列表不刷新的问题
```

## Agent Rules
1. **Do not** introduce dependencies without justification
2. **Do not** hand-edit `project.pbxproj` — use Xcode
3. **Match** existing patterns (MVVM, protocol injection, async/await)
4. **Keep** changes buildable: `xcodebuild -scheme SpaceSwap build`
5. **Verify** tests pass after changes
6. **Follow** the commit style above
