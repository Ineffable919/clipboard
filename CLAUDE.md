# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A macOS clipboard manager (AppKit rewrite of a prior SwiftUI implementation). The SwiftUI reference project is at `./reference` — use it to understand existing layouts and design intent, then re-implement with AppKit idioms.

- **Target**: macOS 15.0+, Swift 6.2+
- **Language**: AppKit-first; SwiftUI only via `NSHostingView`/`NSHostingController` when explicitly requested
- **Default reply language**: Chinese(simplified)

## Build & Development

Open `Clipboard.xcodeproj` in Xcode and build/run with ⌘R. There is no separate CLI build command.

If Xcode MCP is configured, prefer its tools:
- `BuildProject` — build after changes to confirm compilation
- `GetBuildLog` — inspect build errors
- `DocumentationSearch` — verify API availability before writing code
- `XcodeListNavigatorIssues` — check Issue Navigator
- `ExecuteSnippet` — test a snippet in file context

Run SwiftLint before committing: `swiftlint` (no warnings or errors permitted).

## Architecture

### Data Layer

| Class | Role |
|---|---|
| `PasteBoard` | Polls `NSPasteboard` every 0.5 s; filters sensitive/ephemeral types; forwards new items to `PasteDataStore` |
| `PasteDataStore` | In-memory `CurrentValueSubject<[PasteboardModel], Never>` list; owns pagination (50 items/page), search, and CRUD; wraps `PasteSQLManager` |
| `PasteSQLManager` | `actor` wrapping SQLite.swift; stores items in `~/Documents/Clip/Clip.sqlite3` |
| `PasteboardModel` | Single clipboard item; identified by content hash (`uniqueId`); carries raw `data`, `showData` (truncated display copy), and lazy caches for thumbnails, colors, OCR results |

Data flow: `PasteBoard` → `PasteDataStore.addNewItem` → `PasteSQLManager.insert` → `dataList` publisher → `ClipMainViewController`.

### UI Layer

Two display modes toggled by `WindowManager`:
- **Drawer** (`ClipMainWindowController` / `ClipMainViewController`) — slides in from the bottom of the screen
- **Floating** (`ClipFloatingWindowController` / `ClipFloatingViewController`) — free-floating panel

`ClipMainViewController` owns:
- `NSCollectionView` (horizontal scroll) backed by `NSCollectionViewDiffableDataSource`
- `TopBarView` → `TopBarViewModel` — search field (token-based), chip filter row, filter popover
- `AppEnvironment.shared` — `@MainActor` singleton for shared UI state (focus region, selection index path)

Search pipeline: `SearchField` text → `TopBarViewModel.handleQueryChange` → `PasteFilterBuilder.buildFilter` → `PasteDataStore.searchData` → SQL query → `dataList` update → `applySnapshot`.

### Services & Utilities

| Class | Role |
|---|---|
| `CategoryChipStore` | Manages category chips (system + user-defined); `@Published selectedChipId` drives collection filtering |
| `HotKeyManager` | Registers global hotkeys via Carbon `RegisterEventHotKey`; default launch shortcut `⌘⇧V` |
| `ClipActionService` | Paste/copy actions triggered from `ClipMainViewController` |
| `PasteUserDefaults` / `PrefKey` | All user preferences via `UserDefaults`; keys defined in `PrefKey` enum |
| `WindowManager` | Single entry point to show/hide either display mode |

## Key Conventions

- **Layout**: all constraints use SnapKit `snp` API — never raw `NSLayoutConstraint` or anchors directly.
- **Concurrency**: always `async/await`; never `DispatchQueue.main.async` or other GCD patterns.
- **Text search**: use `localizedStandardContains()`, not `contains()`.
- **Localization**: all user-visible strings must use `String(localized: .symbolKey)` / `Text(.symbolKey)` referencing keys in `Localizable.xcstrings` with `extractionState: "manual"`.
- **Number/date formatting**: always `FormatStyle` API — no `DateFormatter`, `NumberFormatter`, or `String(format:)`.
- **No third-party frameworks** without asking first.

## Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

---

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.
