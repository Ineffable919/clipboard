import SwiftUI

@available(macOS 26.0, *)
struct HUDContentView: View {
    // Leave the glass highlight and shadow room to render beyond the visible surface.
    static let effectPadding: CGFloat = 60

    let icon: NSImage?
    let text: String
    let size: CGSize

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
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 26)
            }
            .frame(width: size.width, height: size.height)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .padding(Self.effectPadding)
        }
        // A nonactivating HUD still needs the active glass appearance.
        .environment(\.appearsActive, true)
    }
}
