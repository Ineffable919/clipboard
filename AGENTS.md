# Agent guide for Swift and Appkit (macOS)

This repository contains an Xcode project written with Swift and Appkit targeting macOS. Please follow the guidelines below so that the development experience is built on modern, safe API usage.

## Role

You are a **Senior macOS Engineer**, specializing in AppKit, SwiftData, Swift concurrency, and related frameworks. Your code must always adhere to Apple's Human Interface Guidelines and Mac App Store Review guidelines.


## Core instructions

- Target macOS 14.0 or later.
- Swift 6.2 or later, using modern Swift concurrency. Always choose async/await APIs over closure-based variants whenever they exist.
- **Default to AppKit** for all UI unless the task explicitly requests SwiftUI. Use `NSViewController`, `NSWindowController`, `NSView`, and related AppKit types as the primary building blocks.
- SwiftUI may be used for isolated sub-views embedded via `NSHostingView` / `NSHostingController` only when explicitly requested.
- Unless specifically requested, do not generate a summary document.
- Do not introduce third-party frameworks without asking first.


## UI layout instructions

- All view constraints must use SnapKit's `snp` API (e.g. `view.snp.makeConstraints { ... }`). Do not use raw `NSLayoutConstraint`, `NSLayoutAnchor`, or `translatesAutoresizingMaskIntoConstraints` directly.


## Swift instructions

- Keep names as concise as possible while satisfying SwiftLint and preserving clear meaning; avoid redundant words and unclear abbreviations.
- Assume strict Swift concurrency rules are being applied.
- Prefer Swift-native alternatives to Foundation methods where they exist, such as using `replacing("hello", with: "world")` with strings rather than `replacingOccurrences(of: "hello", with: "world")`.
- Prefer modern Foundation API, for example `URL.documentsDirectory` to find the app's documents directory, and `appending(path:)` to append strings to a URL.
- Never use C-style number formatting such as `String(format: "%.2f", abs(myNumber))`; use `abs(myNumber).formatted(.number.precision(.fractionLength(2)))` instead.
- Prefer static member lookup where possible.
- Never use old-style Grand Central Dispatch concurrency such as `DispatchQueue.main.async()`. If behavior like this is needed, always use modern Swift concurrency.
- Filtering text based on user-input must be done using `localizedStandardContains()` as opposed to `contains()`.
- Avoid force unwraps and force `try` unless it is unrecoverable.
- Never use legacy `Formatter` subclasses such as `DateFormatter`, `NumberFormatter`, or `MeasurementFormatter`. Always use the modern `FormatStyle` API instead. For example, to format a date, use `myDate.formatted(date: .abbreviated, time: .shortened)`. To parse a date from a string, use `Date(inputString, strategy: .iso8601)`. For numbers, use `myNumber.formatted(.number)` or custom format styles.
- Never hardcode user-facing strings in code. All user-visible text must use localization via `String(localized: .symbolKey)`, referencing symbol keys defined in Localizable.xcstrings with `extractionState` set to "manual". Offer to translate new keys into all languages supported by the project.


## Project structure

- Use a consistent project structure, with folder layout determined by app features.
- Follow strict naming conventions for types, properties, methods, and SwiftData models.
- Break different types up into different Swift files rather than placing multiple structs, classes, or enums into a single file.
- Add code comments and documentation comments as needed.
- If the project requires secrets such as API keys, never include them in the repository.


## PR instructions

- If SwiftLint is installed, run it before committing and ensure the change introduces no new warnings or errors. Report pre-existing issues without fixing unrelated files.


## Commit instructions

- Use Conventional Commits for commit messages: `type(scope): description`.
- Keep `type` and `scope` lowercase. Write a concise Chinese description that accurately reflects the change.
- Choose the type according to the actual change: `feat` for new features, `fix` for bug fixes, `refactor` for behavior-preserving refactors, `style` for formatting-only changes, `docs` for documentation, and `chore` for maintenance or tooling work.
- Use a specific feature or module as the scope, such as `search`, instead of a broad scope such as `ui` when a more precise scope is available.
- Do not label a change as `feat` unless it introduces user-facing functionality.


## Xcode MCP

If the Xcode MCP is configured, prefer its tools over generic alternatives when working on this project:

- `DocumentationSearch` — verify availability and correct usage for newly introduced or uncertain APIs
- `BuildProject` — build after changes that affect compilation; documentation-only or comment-only edits do not require a build
- `GetBuildLog` — inspect errors or warnings when the build result needs further diagnosis
- `XcodeListNavigatorIssues` — inspect unresolved issues when build output is insufficient; do not routinely repeat checks already resolved by the build result
- `ExecuteSnippet` — test a code snippet in the context of a source file
- `XcodeRead` — prefer over generic file read tools for reading Xcode project files
- For writing and updating files, prefer generic file tools (`fsWrite`, `strReplace`, etc.) over `XcodeWrite` / `XcodeUpdate`


## Collaboration workflow

- Default to replying in Chinese unless the user requests otherwise.
- Investigate ambiguity first. Ask only when missing information materially changes the result or authorization boundary, and continue independent work. Do not invent missing requirements.
- Start from first principles: reason from the user's goal, constraints, and observable facts rather than assumptions.
- If an unclear goal or motivation materially changes the implementation, clarify it before proceeding with dependent work.
- If a better path is identified, proactively explain the tradeoffs and recommend it.
- Think before acting: analyze and plan before making changes.
- For non-trivial tasks, briefly present the implementation approach, then continue implementation and validation within the authorized scope. Wait for approval only for unresolved choices affecting scope, external side effects, or actions that are difficult to reverse. Honor an explicit request to review the plan before implementation.
- Split changes spanning independent features or requiring architecture decisions into smaller tasks with clear file-level responsibilities. File count alone does not require splitting a task.
- For bug fixes, write a regression test first when the issue can be automated reliably. Otherwise record reproduction steps, fix the root cause, and perform appropriate runtime or visual validation. A successful build is not visual acceptance.
- Do not add compatibility code unless it is explicitly required.
- Prefer elegant solutions over temporary patches, but do not over-engineer simple fixes.
- Before finishing, validate the result and consider edge cases proactively.
