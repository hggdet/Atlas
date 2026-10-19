import SwiftUI

/// Borderless Liquid Glass — the glass is defined by light and refraction
/// only, never by a stroke/border line (standing design rule, 2026-10-19).
/// On iOS 26+ this is Apple's real native glass (`.glassEffect`, which
/// refracts the content behind the surface). On older systems it degrades
/// to a thin material with a soft top sheen — still no border line.
enum GlassShape {
    case rounded(CGFloat)
    case capsule
    case circle
}

struct GlassModifier: ViewModifier {
    var shape: GlassShape = .rounded(24)
    var tint: Color? = nil

    func body(content: Content) -> some View {
        switch shape {
        case .rounded(let radius):
            apply(content, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
        case .capsule:
            apply(content, in: Capsule(style: .continuous))
        case .circle:
            apply(content, in: Circle())
        }
    }

    @ViewBuilder
    private func apply<S: Shape>(_ content: Content, in shape: S) -> some View {
        if #available(iOS 26.0, *) {
            if let tint {
                content.glassEffect(.regular.tint(tint).interactive(), in: shape)
            } else {
                content.glassEffect(.regular.interactive(), in: shape)
            }
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
                .overlay(
                    // Top-light sheen only — light, not a border.
                    shape.fill(
                        LinearGradient(
                            colors: [.white.opacity(0.22), .white.opacity(0.0)],
                            startPoint: .top, endPoint: .center
                        )
                    )
                    .allowsHitTesting(false)
                )
                .shadow(color: .black.opacity(0.12), radius: 10, y: 3)
        }
    }
}

/// Ink for text and icons: near-black in light mode, near-white in dark mode.
var adaptiveInk: Color {
    Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 0.97, alpha: 1)
            : UIColor(white: 0.06, alpha: 1)
    })
}

extension View {
    /// Rounded-rectangle borderless glass (cards, panels, sheets).
    func glass(cornerRadius: CGFloat = 24, tint: Color? = nil) -> some View {
        modifier(GlassModifier(shape: .rounded(cornerRadius), tint: tint))
    }

    /// True pill glass — for the floating search bar.
    func glassPill(tint: Color? = nil) -> some View {
        modifier(GlassModifier(shape: .capsule, tint: tint))
    }

    /// Circular glass — for the round map buttons.
    func glassCircle(tint: Color? = nil) -> some View {
        modifier(GlassModifier(shape: .circle, tint: tint))
    }
}

struct GlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .glass(cornerRadius: 20)
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// Round map buttons: pure glass circle, no border, press squash.
struct GlassCircleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .glassCircle()
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
