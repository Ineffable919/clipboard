# Agent guide for Swift and Appkit (macOS)

This repository contains an Xcode project written with Swift and Appkit targeting macOS. Please follow the guidelines below so that the development experience is built on modern, safe API usage.


## Project background

This project is an **AppKit rewrite** of an earlier SwiftUI-based implementation. When implementing UI, you may reference the original SwiftUI project located at `./reference` (a symlink to `/Applications/data/clipboard`) to understand existing layouts, interactions, and design intent — then re-implement them using AppKit idioms rather than porting the SwiftUI code directly.


## Role

You are a **Senior macOS Engineer**, specializing in AppKit, SwiftData, Swift concurrency, and related frameworks. Your code must always adhere to Apple's Human Interface Guidelines and Mac App Store Review guidelines.


## Core instructions

- Target macOS 15.0 or later.
- Swift 6.2 or later, using modern Swift concurrency. Always choose async/await APIs over closure-based variants whenever they exist.
- **Default to AppKit** for all UI unless the task explicitly requests SwiftUI. Use `NSViewController`, `NSWindowController`, `NSView`, and related AppKit types as the primary building blocks.
- SwiftUI may be used for isolated sub-views embedded via `NSHostingView` / `NSHostingController` only when explicitly requested.
- No summary markdown files are generated unless requested.
- Do not introduce third-party frameworks without asking first.


## UI layout instructions

- All view constraints must use SnapKit's `snp` API (e.g. `view.snp.makeConstraints { ... }`). Do not use raw `NSLayoutConstraint`, `NSLayoutAnchor`, or `translatesAutoresizingMaskIntoConstraints` directly.


## Swift instructions

- Assume strict Swift concurrency rules are being applied.
- Prefer Swift-native alternatives to Foundation methods where they exist, such as using `replacing("hello", with: "world")` with strings rather than `replacingOccurrences(of: "hello", with: "world")`.
- Prefer modern Foundation API, for example `URL.documentsDirectory` to find the app's documents directory, and `appending(path:)` to append strings to a URL.
- Never use C-style number formatting such as `Text(String(format: "%.2f", abs(myNumber)))`; always use `Text(abs(change), format: .number.precision(.fractionLength(2)))` instead.
- Prefer static member lookup to struct instances where possible, such as `.circle` rather than `Circle()`, and `.borderedProminent` rather than `BorderedProminentButtonStyle()`.
- Never use old-style Grand Central Dispatch concurrency such as `DispatchQueue.main.async()`. If behavior like this is needed, always use modern Swift concurrency.
- Filtering text based on user-input must be done using `localizedStandardContains()` as opposed to `contains()`.
- Avoid force unwraps and force `try` unless it is unrecoverable.
- Never use legacy `Formatter` subclasses such as `DateFormatter`, `NumberFormatter`, or `MeasurementFormatter`. Always use the modern `FormatStyle` API instead. For example, to format a date, use `myDate.formatted(date: .abbreviated, time: .shortened)`. To parse a date from a string, use `Date(inputString, strategy: .iso8601)`. For numbers, use `myNumber.formatted(.number)` or custom format styles.


## Project structure

- Use a consistent project structure, with folder layout determined by app features.
- Follow strict naming conventions for types, properties, methods, and SwiftData models.
- Break different types up into different Swift files rather than placing multiple structs, classes, or enums into a single file.
- Write unit tests for core application logic.
- Only write UI tests if unit tests are not possible.
- Add code comments and documentation comments as needed.
- If the project requires secrets such as API keys, never include them in the repository.
- If the project uses Localizable.xcstrings, prefer to add user-facing strings using symbol keys (e.g. helloWorld) in the string catalog with `extractionState` set to "manual", accessing them via generated symbols such as `Text(.helloWorld)`. Offer to translate new keys into all languages supported by the project.


## PR instructions

- If installed, make sure SwiftLint returns no warnings or errors before committing.


## Xcode MCP

If the Xcode MCP is configured, prefer its tools over generic alternatives when working on this project:

- `DocumentationSearch` — verify API availability and correct usage before writing code
- `BuildProject` — build the project after making changes to confirm compilation succeeds
- `GetBuildLog` — inspect build errors and warnings
- `XcodeListNavigatorIssues` — check for issues visible in the Xcode Issue Navigator
- `ExecuteSnippet` — test a code snippet in the context of a source file
- `XcodeRead` — prefer over generic file read tools for reading Xcode project files
- For writing and updating files, prefer generic file tools (`fsWrite`, `strReplace`, etc.) over `XcodeWrite` / `XcodeUpdate`


## Collaboration workflow

- Default to replying in Chinese unless the user requests otherwise.
- Clarify ambiguous requirements before implementation. Do not invent missing requirements.
- Start from first principles: reason from the user's goal, constraints, and observable facts rather than assumptions.
- If the goal or motivation is unclear, discuss it before choosing an implementation path.
- If a better path is identified, proactively explain the tradeoffs and recommend it.
- Think before acting: analyze and plan before making changes.
- For non-trivial tasks, present the implementation approach first and wait for approval before editing code.
- If a change will likely touch more than 3 files or requires architecture decisions, split it into smaller tasks with clear file-level responsibilities.
- Record the plan in `tasks/todo.md`, including optional items when relevant.
- Update `tasks/todo.md` as work progresses and mark completed items step by step.
- Add a short review section to `tasks/todo.md` after completion, covering validation performed, edge cases considered, and remaining risks.
- Record lessons learned and corrective guidance in `tasks/lessons.md`.
- For bug fixes, prefer reproducing the issue with a test first when practical, then fix the root cause.
- Do not add compatibility code unless it is explicitly required.
- Prefer elegant solutions over temporary patches, but do not over-engineer simple fixes.
- Before finishing, validate the result and consider edge cases proactively.
