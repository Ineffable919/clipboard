<p align="center">
    <div align="center"><img src=Clipboard/Resource/Assets.xcassets/AppIcon.appiconset/icon-256.png width=135  /></div>
    <h2 align="center">Clipboard</h2>
    <div align="center">A macOS clipboard manager that helps you manage and use your clipboard history more efficiently.
</div>
    <div align="center"><strong>English</strong> | <a href="https://github.com/Ineffable919/clipboard/blob/master/README.md">中文</a></div>
</p>

<img src="temp.png">

## Download

Download the latest version [releases](https://github.com/Ineffable919/clipboard/releases/latest)


## Features

- **Real-time Clipboard Monitoring**: Automatically captures and saves text, images, and files you copy
- **Smart Categorization**: Automatically organizes content by text, images, and file types
- **History Records**: Saves your clipboard history for easy access anytime
- **Customizable Settings**: Supports custom categories and configurable history retention periods
- **Quick Search**: Quickly find history records using keywords
- **Intuitive Interface**: Modern card-based UI design with simple and intuitive operations, supports both light and dark modes
- **Quick Operations**:
  - Double-click to paste directly
  - Shift + mouse scroll
  - Spacebar to preview content
  - Keyboard navigation support
  - Right-click menu for more options
- **Safe Deletion**: Confirmation required to avoid accidental deletions
- **Drag & Drop Support**: Drag content to other applications

## System Requirements

- macOS 14.0 or later (Compatible with macOS 26)
- Supports Apple Silicon (arm64) and Intel (x86_64) architectures

## How to Use

1. Copy any content normally (text, images, or files)
2. Open the Clipboard app to view history
3. Interact with history records using:
   - Double-click an item to paste directly
   - Single-click to select, then press Enter to paste
   - Press Spacebar to preview content
   - Use left/right arrow keys to navigate
   - Right-click an item to open context menu for more actions

## Keyboard Shortcuts

- `ESC`: Close the app window
- `← →`: Navigate between history records
- `Space`: Preview selected item
- `↩`: Paste selected item
- `Shift + ⏎`: Paste as plain text
- `⌘ + C`: Copy selected item to clipboard
- `Delete`: Delete selected item

## FAQ

### App won't open?

1. Check System Settings -> Privacy & Security -> Allow applications from the following sources.
2. Try the following commands:
``` sh
sudo xattr -r -d com.apple.quarantine /Applications/Clipboard.app 
sudo codesign --force --deep --sign - /Applications/Clipboard.app
```

### Accessibility permissions lost after app update?
  - Please use version 0.3.1, as the subsequent versions have resolved this issue.


## License

This project is licensed under the Creative Commons Attribution-NonCommercial 4.0 International Public License. See the [LICENSE](LICENSE) file for details.