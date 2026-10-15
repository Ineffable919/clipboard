import AppKit

extension ChipButton {
    enum Size {
        case regular
        case small
        case mini

        var isCompact: Bool { self != .regular }

        var iconContainerSize: CGFloat { isCompact ? 14 : 16 }
        var smallIconPt: CGFloat { isCompact ? 10 : 12 }
        var dotRadius: CGFloat { isCompact ? 5 : 6 }

        var labelFontSize: CGFloat {
            switch self {
            case .regular: NSFont.systemFontSize
            case .small: NSFont.smallSystemFontSize
            case .mini: NSFont.smallSystemFontSize - 1
            }
        }

        var cornerRadius: CGFloat {
            if #available(macOS 26.0, *), self == .mini {
                return 8
            }
            return isCompact ? Const.btnRadius : Const.radius
        }

        func contentInsets(dotMode: Bool) -> NSEdgeInsets {
            var horizontal: CGFloat = switch self {
            case .regular: dotMode ? Const.space6 : Const.space10
            case .small: dotMode ? Const.space4 : Const.space6
            case .mini: dotMode ? Const.space2 : Const.space4
            }
            let vertical: CGFloat = switch self {
            case .regular: Const.space6
            case .small: 3
            case .mini: 2
            }
            if #available(macOS 26.0, *), isCompact {
                horizontal += Const.space2
            }
            return NSEdgeInsets(top: vertical, left: horizontal, bottom: vertical, right: horizontal)
        }
    }
}
