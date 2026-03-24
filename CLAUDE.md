# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Building

Open `Clipboard.xcodeproj` in Xcode and build/run from there. There is no command-line build script. The app targets macOS 15+.

## Architecture

This is a macOS clipboard manager app (SwiftUI + AppKit). The codebase uses the `@Observable` macro (Swift 5.9+) throughout — no `ObservableObject`/`@Published` patterns.

### Startup flow

`ClipboardApp` (SwiftUI `@main`) → `AppDelegate` → sets up:
- `StatusBarController.shared` — menu bar icon and context menu
- `WindowManager.shared` — coordinates the two display modes
- `PasteBoard.main` + `PasteDataStore.main` — clipboard monitoring and persistence

### Display modes

Two mutually exclusive window modes toggled via `WindowManager`:
- **Drawer** (`ClipMainWindowController`) — side panel that slides in from screen edge
- **Floating** (`ClipFloatingWindowController`) — small floating window near cursor

### Data layer

```
NSPasteboard (0.5s poll)
    └─ PasteBoard          — detects changes, filters sensitive/ephemeral types, creates PasteboardModel
        └─ PasteDataStore  — @Observable store, pages 50 items at a time from SQLite via PasteSQLManager
            └─ PasteboardModel — single clipboard entry (text, image, file, rtf, url, color)
```

`PasteDataStore.main` is the single source of truth for the displayed list. It supports search, tag/chip filtering, and paginated loading (`loadMore`).

### Key singletons

| Class | Role |
|---|---|
| `PasteBoard.main` | NSPasteboard monitor (timer-based, 0.5s interval) |
| `PasteDataStore.main` | SQLite-backed observable list of clipboard entries |
| `CategoryChipStore` | Manages user-defined category chips and their filter state |
| `ClipActionService.shared` | Handles paste/copy/delete actions on `PasteboardModel` items |
| `WindowManager.shared` | Toggles between drawer and floating windows |
| `StatusBarController.shared` | Menu bar item, pause/resume monitoring |
| `AppEnvironment` | Per-window transient UI state (focus field, delete mode, dragging item) |

### View layer

- `HistoryViewModel` — drives both `HistoryView` (drawer) and `FloatingHistoryView` (floating); holds selection, active item, scroll position, quick-paste state
- `AppEnvironment` is injected via SwiftUI environment and scoped to a window
- Views live under `Clipboard/Main/View/main/` (drawer) and `Clipboard/Main/View/Floating/` (floating)

### Sensitive/ephemeral type filtering

`PasteBoard` skips entries whose UTI types include known password manager types (1Password, Bitwarden, etc.) or transient pasteboard types. See `PasteBoard.sensitiveTypes` and `PasteBoard.ephemeralTypes`.

### Auto-update

Sparkle (`SPUStandardUpdaterController`) is integrated in `AppDelegate`. Update state is surfaced through `UpdateManager.shared`.

## Conventions

- All UI and model code runs on `@MainActor`. Database calls go through `PasteSQLManager` which executes on a background actor.
- `PasteUserDefaults` is the single access point for `UserDefaults`; `PrefKey` enumerates all keys.
- Localized strings use `String(localized:)` with string resource keys defined in `Localizable.xcstrings`.
- `log` is a global logger used across the codebase (not `print`/`NSLog`).
