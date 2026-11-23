import SwiftUI

enum StratoTheme {
    static let skyCyan = Color(red: 0.35, green: 0.82, blue: 1.0)
    static let radarEmerald = Color(red: 0.25, green: 0.90, blue: 0.65)
    static let amberBeacon = Color(red: 1.0, green: 0.72, blue: 0.28)
    static let stratosphereIndigo = Color(red: 0.38, green: 0.48, blue: 0.98)
}

struct StratoGlassSurface<S: Shape>: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let shape: S
    let interactive: Bool
    let tint: Color?

    func body(content: Content) -> some View {
        if reduceTransparency {
            content
                .background(.ultraThickMaterial, in: shape)
                .overlay(shape.stroke(.white.opacity(0.18), lineWidth: 0.8))
        } else {
            if let tint {
                if interactive {
                    content.glassEffect(.regular.tint(tint).interactive(), in: shape)
                } else {
                    content.glassEffect(.regular.tint(tint), in: shape)
                }
            } else {
                if interactive {
                    content.glassEffect(.regular.interactive(), in: shape)
                } else {
                    content.glassEffect(.regular, in: shape)
                }
            }
        }
    }
}

extension View {
    func stratoGlassCard(
        cornerRadius: CGFloat = 26,
        interactive: Bool = false,
        tint: Color? = nil
    ) -> some View {
        modifier(
            StratoGlassSurface(
                shape: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous),
                interactive: interactive,
                tint: tint
            )
        )
    }

    func stratoGlassCapsule(
        interactive: Bool = true,
        tint: Color? = nil
    ) -> some View {
        modifier(
            StratoGlassSurface(
                shape: Capsule(),
                interactive: interactive,
                tint: tint
            )
        )
    }
}
