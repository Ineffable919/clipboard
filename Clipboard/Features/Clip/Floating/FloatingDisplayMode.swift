import AppKit

enum FloatingDisplayMode: Int, CaseIterable {
    case standard
    case minimal

    var title: String {
        switch self {
        case .standard: String(localized: .floatingModeStandard)
        case .minimal: String(localized: .floatingModeMinimal)
        }
    }

    var windowSize: NSSize {
        NSSize(width: self == .standard ? FloatConst.floatWindowWidth : 300, height: self == .standard ? 650 : 560)
    }

    var headerHeight: CGFloat { self == .standard ? 90 : 78 }
    var windowRadius: CGFloat {
        if #available(macOS 26.0, *), self == .minimal {
            return 20
        }
        return Const.windowRadis
    }
    var footerHeight: CGFloat { self == .standard ? 32 : 24 }
    var cardHeight: CGFloat { self == .standard ? 60 : 44 }
    var cardSpacing: CGFloat { self == .standard ? 6 : 4 }
    var cardInset: CGFloat { self == .standard ? 10 : 12 }
    var cardRadius: CGFloat { self == .standard ? Const.radius : 8 }
}
