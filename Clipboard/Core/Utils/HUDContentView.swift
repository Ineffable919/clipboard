import SwiftUI

@available(macOS 26.0, *)
struct HUDContentView: View {

    static let effectPadding: CGFloat = 60

    let icon: NSImage?
    let text: String
    let size: CGSize
    var textColor: Color = .secondary

    var body: some View {
        GlassEffectContainer {
            ZStack {
                if let icon {
                    Image(nsImage: icon)
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(.secondary)
                        .frame(width: 100, height: 100)
                        .offset(y: -16)
                        .accessibilityHidden(true)
                }

                Text(text)
                    .font(.title)
                    .foregroundStyle(textColor)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 26)
            }
            .frame(width: size.width, height: size.height)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .padding(Self.effectPadding)
        }
        // A nonactivating HUD still needs the active glass appearance
        .environment(\.appearsActive, true)
    }
}

#if DEBUG
#Preview("macOS 26+ · Liquid Glass", traits: .fixedLayout(width: 320, height: 320)) {
    if #available(macOS 26.0, *) {
        HUDContentView(
            icon: NSImage(systemSymbolName: "checkmark", accessibilityDescription: nil),
            text: String(localized: "hudCopySucceeded"),
            size: CGSize(width: 200, height: 200),
            textColor: .primary
        )
    }
}

#Preview("macOS 14–25 · HUD Material", traits: .fixedLayout(width: 248, height: 248)) {
    HUDLegacyPreview(textColor: .primary)
        .frame(width: 200, height: 200)
        .padding(24)
}

private struct HUDLegacyPreview: NSViewRepresentable {
    var textColor: Color = .secondary

    func makeNSView(context: Context) -> NSView {
        HUDManager.makeLegacyPreview(
            icon: NSImage(systemSymbolName: "checkmark", accessibilityDescription: nil),
            text: String(localized: "hudCopySucceeded"),
            textColor: textColor
        )
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        HUDManager.updateLegacyPreview(
            nsView,
            icon: NSImage(systemSymbolName: "checkmark", accessibilityDescription: nil),
            text: String(localized: "hudCopySucceeded"),
            textColor: textColor
        )
    }
}
#endif
