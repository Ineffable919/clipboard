# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

@AGENTS.md

## Commands

Xcode project `Clipboard.xcodeproj`, scheme `Clipboard` (macOS 14+, Swift Package Manager deps: SnapKit, SQLite.swift, Sparkle, swift-markdown). There are no test targets and no `.swiftlint.yml`.

```bash
xcodebuild -project Clipboard.xcodeproj -scheme Clipboard -configuration Debug build
```

Prefer the Xcode MCP `BuildProject` when available (see AGENTS.md).

Release tooling lives in `scripts/` (`build.sh <version> [build] [arch]`, `release.sh`, `sign_update.sh`) and is git-ignored local automation; `scripts/release-note.html` is the canonical release-note source. For releases use the `clipboard-release` skill (`.claude/skills/clipboard-release`). Version branches are named `v<version>`; `master` is the release branch.

## Architecture

Two Xcode targets share one SQLite database:

- **`Clipboard`** (the menu-bar app, `Clipboard/`) — AppKit app, entry via `App/AppDelegate.swift`.
- **`clipmcp`** (`Clipboard/AI/`) — a tiny stdio JSON-RPC MCP server (`main.swift` → `MCPHandler` → `MCPTools`) exposing clipboard history to AI clients. It exits immediately unless the enable-flag file (`ClipboardPaths.mcpEnableFlag`, toggled by `MCPEnableFlag`) exists.
- `Core/Shared/ClipboardSchema.swift` is compiled into **both** targets: it holds the `Col` column definitions and `ClipboardPaths`. Change the DB schema there, and keep it free of app-only dependencies.

### Startup flow

`AppDelegate.applicationDidFinishLaunching` sets up the status bar, then `initClipboardAsync`: `PasteDataStore.main.setup()` → `PasteBoard.main.startListening()` (pasteboard polling) → local key monitor → `HotKeyManager` → welcome window.

### Data layer (`Core/Data`)

- `PasteBoard` watches `NSPasteboard` and builds `PasteboardModel`s (`Core/Models/Pasteboard`); `PasteBoard+Writing` writes items back (paste / plain-text paste).
- `PasteSQLManager` is an **actor** owning the SQLite connection (`Clip.sqlite3` under Application Support/`<bundle id>`); split by extension (Query / Write / Migration / Transfer import-export / Apps).
- `PasteDataStore` (singleton `.main`) is the UI-facing store: paged `dataList` (`CurrentValueSubject`, page size 50), search/filter state, revision counters, and a `DataChangeType` enum that views use to apply incremental updates. Ingestion, mapping and maintenance are in extensions.
- Sort order (`PasteOrder`) is persisted via `sort_order`; "move to first" and reordering go through it.

### UI (`Features/`)

Organized per feature, each with Controller / View / ViewModel subfolders: `Clip` (main panel: `Card`, `Top` header/search/chips, `Floating` display mode, `Preview`), `Edit` (text + JSON editor), `Setting`, `Welcome`, `StatusBar`. `ClipWindowView` hosts the main panel. Window/HUD/hotkey plumbing is in `Core/Utils` (`WindowManager`, `HUDManager`, `HotKeyManager`). Settings are keyed through `PrefKey` / `PasteUserDefaults`.

### Services and caches

`Core/Services` holds OCR / Live Text (`OCRViewService`, `LiveTextService`), category chips, app-icon color extraction, and filter building (`PasteFilterBuilder`); `Core/Cache` holds icon/thumbnail/metadata caches. `LegacyConfigMigrator` and `PasteSQLManager+Migration` handle upgrades from older versions.

### Localization

All strings live in `Resource/Localizable.xcstrings` with manual symbol keys; use the `add-string` skill to add new keys with translations for every supported language.
