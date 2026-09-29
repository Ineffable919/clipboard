import SwiftUI

struct WelcomeControlButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.primary)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, minHeight: 24)
            .background(
                (colorScheme == .dark ? Color.white : .black)
                    .opacity(configuration.isPressed ? 0.14 : 0.08),
                in: .rect(cornerRadius: 6)
            )
    }
}

#Preview {
    Button(.permissionOpenSettings) {}
        .buttonStyle(WelcomeControlButtonStyle())
        .frame(width: 104)
        .padding(24)
}
