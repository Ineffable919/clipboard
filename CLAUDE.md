@AGENTS.md

# CLAUDE.md

## Build & Development

Open `Clipboard.xcodeproj` in Xcode and build/run with ⌘R. There is no separate CLI build command.

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

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

---

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.
