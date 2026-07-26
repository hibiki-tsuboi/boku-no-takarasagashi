# Repository Guidelines

## Project Structure & Module Organization

`BokuNoTakarasagashi/` contains the iOS application source. `BokuNoTakarasagashiApp.swift` creates the SwiftUI scene, `PersistenceBootstrapView.swift` creates the SwiftData container, `ContentView.swift` contains the parent dashboard, and `TreasureModels.swift` defines the persisted models. Put images, colors, and app icons in `BokuNoTakarasagashi/Assets.xcassets`. Project settings, targets, and schemes live in `BokuNoTakarasagashi.xcodeproj`; edit them through Xcode when practical. Keep new views and models in separate, descriptively named Swift files.

## Build, Test, and Development Commands

- `open BokuNoTakarasagashi.xcodeproj` opens the project for local development and SwiftUI previews.
- `xcodebuild -project BokuNoTakarasagashi.xcodeproj -scheme BokuNoTakarasagashi -configuration Debug -destination 'generic/platform=iOS Simulator' build` performs a command-line debug build without selecting a specific simulator.
- `xcodebuild -project BokuNoTakarasagashi.xcodeproj -scheme BokuNoTakarasagashi -showdestinations` lists destinations available for running or testing.

Use Xcode’s Run action for interactive development. The deployment target is iOS 26.0, so use a compatible Xcode and simulator runtime.

## Coding Style & Naming Conventions

Follow standard Swift API design guidelines and the existing four-space indentation. Use `UpperCamelCase` for types and views, `lowerCamelCase` for properties and functions, and name files after their primary type (for example, `TreasureMapView.swift`). Keep SwiftUI view bodies declarative; move persistence or reusable behavior into focused methods or types. No SwiftLint or SwiftFormat configuration is present, so use Xcode’s re-indent command and keep warnings at zero.

## Testing Guidelines

Unit tests live under the `BokuNoTakarasagashiTests/` target. Add UI tests under a `BokuNoTakarasagashiUITests/` target when needed. Name test files `<TypeName>Tests.swift` and test observable behavior, especially SwiftData insert, delete, migration, authentication recovery, and lifecycle paths. Run tests with Xcode’s Test action or `xcodebuild test` using a concrete destination returned by `-showdestinations`.

## Commit & Pull Request Guidelines

Use concise, imperative subjects and keep each commit focused. Recent history uses short Japanese descriptions, often with a gitmoji prefix. Pull requests should explain the user-visible change, list validation performed, link relevant issues, and include simulator screenshots or recordings for UI changes. Call out SwiftData schema changes and any migration impact explicitly.
