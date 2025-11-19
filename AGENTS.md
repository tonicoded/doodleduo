# Repository Guidelines

## Project Structure & Module Organization
SwiftUI sources live in `doodleduo/`. `doodleduoApp.swift` wires up the scene, and `ContentView.swift` holds the primary UI logic. Shared visual assets belong in `doodleduo/Assets.xcassets`, and app metadata stays in `doodleduo/Info.plist`. Unit specs reside in `doodleduoTests/`, while UI automation lives under `doodleduoUITests/` (split into smoke tests and launch tests). Keep any helper types next to their consumers; if a file grows beyond ~200 lines, create a focused Swift file in the same folder to retain one-view-per-file clarity.

## Build, Test, and Development Commands
Use Xcode 15+ or run from the CLI:
* `open doodleduo.xcodeproj` — launches the workspace.
* `xcodebuild -scheme doodleduo -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15' clean build` — full clean build.
* `xcodebuild test -scheme doodleduo -destination 'platform=iOS Simulator,name=iPhone 15'` — runs all unit and UI tests headlessly.
Simulator logging is easiest via Xcode’s “Run” action with the Debug console visible.

## Coding Style & Naming Conventions
Follow Swift API Design Guidelines: type and view names in PascalCase (`DrawingCanvasView`), members in camelCase, and constants prefixed with context (`drawingColor`, `canvasWidth`). Indent with four spaces and keep lines ≤120 chars so diffs remain readable. Prefer structs, immutable state, and SwiftUI modifiers grouped from high- to low-level (layout, styling, behaviors). Run Xcode’s “Editor → Structure → Re-Indent” before committing and resolve warnings—treat warnings as build failures. Localizable strings should reference `NSLocalizedString` keys defined near their usage until a dedicated strings file is added.

## Testing Guidelines
Tests use XCTest. Name test files after the subject (`ContentViewTests`) and methods as `testScenario_Expectation`. Unit specs live in `doodleduoTests` and should isolate business logic such as drawing-state reducers. UI tests in `doodleduoUITests` must verify happy-path taps plus launch regressions (see `doodleduoUITestsLaunchTests.swift`). Run `xcodebuild test …` before every push; new UI features require at least one assertion that the rendered view hierarchy changes as expected.

## Commit & Pull Request Guidelines
Write commits in the imperative mood (“Add layered brush preview”) with a one-sentence body explaining the why when non-trivial. Reference issues via `Fixes #ID` to auto-close. PRs should summarize scope, list testing evidence (command output or screenshots), and call out any follow-up TODOs. Include simulator screenshots for UI-visible work and mention new assets or permissions added to `Info.plist` so reviewers can double-check entitlements.
