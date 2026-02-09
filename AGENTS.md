# SpaceSwap – Agent Guide

Generated for AI/code agents working in this repo.

## 0. Overview

SpaceSwap 是一个面向系统相册的空间优化工具 App，主要通过访问系统相册，对体积较大的视频资源进行压缩以节省设备存储空间。同时也支持对照片等其他多媒体资源进行压缩处理，但核心场景是「大视频压缩腾出更多可用空间」。

## 1. Stack & Project Layout
- Platform: iOS, SwiftUI, Xcode project `SpaceSwap.xcodeproj`.
- Targets:
  - `SpaceSwap` – main app
  - `SpaceSwapTests` – unit tests
  - `SpaceSwapUITests` – UI tests
- Source layout (top level):

```text
./
├─ SpaceSwap.xcodeproj/        # Xcode project definition
├─ SpaceSwap/                  # App target sources & assets
│  ├─ SpaceSwapApp.swift       # App entry point (SwiftUI @main)
│  ├─ ContentView.swift        # Root content view
│  └─ Assets.xcassets/         # AppIcon, AccentColor, etc.
├─ SpaceSwapTests/             # XCTest unit tests
│  └─ SpaceSwapTests.swift
└─ SpaceSwapUITests/           # XCTest UI tests
   ├─ SpaceSwapUITests.swift
   └─ SpaceSwapUITestsLaunchTests.swift
```

No workspaces, SPM packages, or additional modules are defined in `project.pbxproj` at time of writing.

## 2. Build, Run, and Test

### 2.1 CLI (xcodebuild)

Project name: `SpaceSwap`  
Primary scheme: `SpaceSwap`

Run from repo root:

```bash
# Build app for iOS Simulator (Debug)
xcodebuild \
  -scheme SpaceSwap \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
  build

# Run all unit tests
xcodebuild \
  -scheme SpaceSwap \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
  test \
  -only-testing:SpaceSwapTests

# Run all UI tests
xcodebuild \
  -scheme SpaceSwap \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
  test \
  -only-testing:SpaceSwapUITests
```

### 2.2 Running a Single Test Case / Method

Use `-only-testing` / `-skip-testing` with XCTest identifiers:

```bash
# Single test class (unit)
xcodebuild \
  -scheme SpaceSwap \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
  test \
  -only-testing:SpaceSwapTests/SpaceSwapTests

# Single test method (unit)
xcodebuild \
  -scheme SpaceSwap \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
  test \
  -only-testing:SpaceSwapTests/SpaceSwapTests/testExample

# Single UI test class
xcodebuild \
  -scheme SpaceSwap \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
  test \
  -only-testing:SpaceSwapUITests/SpaceSwapUITests

# Single UI test method
xcodebuild \
  -scheme SpaceSwap \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
  test \
  -only-testing:SpaceSwapUITests/SpaceSwapUITests/testExample
```

Replace `iPhone 16` and `OS=latest` with available simulators if needed.

### 2.3 Xcode UI
- Scheme: `SpaceSwap`.
- Use the standard Test (⌘U) / Run (⌘R) flows.
- Configure which tests to run via the Test navigator; agents should not assume custom schemes exist.

## 3. Linting, Formatting, and Tools

- No repo-level config detected for:
  - SwiftLint (`.swiftlint.yml` / `.swiftlint.yaml`).
  - SwiftFormat (`.swiftformat`).
  - EditorConfig (`.editorconfig`).
  - SPM (`Package.swift`).
- Therefore, default to Xcode/Swift compiler diagnostics.

If you introduce SwiftLint / SwiftFormat or SPM later, update this section with:
- Installation / invocation commands.
- Locations of config files.

## 4. Code Style & Conventions (Swift / SwiftUI)

These are conventions for agents to follow; keep them consistent across new code.

### 4.1 Imports
- Minimal imports; prefer `import SwiftUI` at top for views.
- Avoid wildcard or redundant imports (Swift does not support `*`, but avoid unused frameworks).
- Group imports in single block, no blank lines between them unless separating Apple vs third-party (none yet).

### 4.2 Types & Optionals
- Prefer explicit types for public API and stored properties, rely on inference for obvious locals.
- Avoid force unwraps (`!`) and `try!` in production paths.
- For UI tests and sample code, `!` should still be minimized; prefer safe optional binding:

```swift
if let value = optionalValue {
    // use value
}
```

### 4.3 Naming
- Types: `UpperCamelCase` (`SpaceSwapApp`, `ContentView`).
- Methods, functions, variables: `lowerCamelCase`.
- Test classes end with `Tests` (e.g., `SpaceSwapTests`, `SpaceSwapUITests`).
- Test methods start with `test` and describe behavior: `testExample`, `testLaunchingAppShowsHome`.

### 4.4 SwiftUI Structure
- `SpaceSwapApp.swift` contains the `@main` app struct and scene hierarchy.
- `ContentView.swift` is the entry view; keep it lightweight.
- Prefer small focused views over monoliths; extract subviews when complexity grows.

Recommended patterns:
- Use `@State`, `@Binding`, `@ObservedObject`, `@StateObject` appropriately; avoid global state.
- Derive computed properties instead of duplicating state.

### 4.5 Error Handling
- Use Swift `throw` / `do { try ... } catch { ... }` for recoverable failures.
- Never leave `catch {}` blocks empty; log or assert with minimal information.
- For UI-level failures, surface via user-visible state rather than `fatalError`, unless truly unrecoverable.

### 4.6 Testing Conventions
- Use `XCTestCase` subclasses under `SpaceSwapTests` / `SpaceSwapUITests`.
- Prefer `XCTAssertEqual`, `XCTAssertTrue`, etc. with messages that clarify intent.
- UI tests use `XCUIApplication` and queries; avoid brittle element hierarchies when possible.

## 5. File & Project Organization

- Keep app code under `SpaceSwap/`.
- Keep test-only helpers under the corresponding `SpaceSwapTests/` or `SpaceSwapUITests/` folders.
- Assets remain in `Assets.xcassets`; avoid hard‑coding asset names in many places—wrap in simple helpers if needed.
- If you add new feature groups, prefer folders under `SpaceSwap/` like `Features/`, `Components/`, `Services/` rather than flattening everything.

## 6. CI / Automation

- No `.github/workflows`, `Fastfile`, or other CI/automation config found.
- If adding CI later (GitHub Actions, Fastlane, etc.), document:
  - Primary workflow entry file.
  - Default build/test matrix.
  - Any required environment variables or secrets.

## 7. Copilot / Cursor Rules

- No Cursor rules found in `.cursor/rules/` or `.cursorrules`.
- No Copilot instruction file found at `.github/copilot-instructions.md`.
- Agents should therefore follow this `AGENTS.md` as the primary guidance.

## 8. Agent Working Agreements

- Do not introduce new dependencies or modules without clear justification.
- Match existing target structure; if you create new targets, update `SpaceSwap.xcodeproj` via Xcode, not by hand‑editing `project.pbxproj`.
- Keep changes buildable with `xcodebuild -scheme SpaceSwap build`.
- When adding tests, ensure they are runnable individually via `-only-testing` identifiers.
