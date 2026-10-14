import SwiftUI

/// Keep glass in the functional layer; content retains standard surfaces.
struct StudioGlassButton: ViewModifier {
    var prominent = false
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @ViewBuilder func body(content: Content) -> some View {
        if #available(macOS 26.0, *), !reduceTransparency, contrast != .increased {
            if prominent { content.buttonStyle(.glassProminent) }
            else { content.buttonStyle(.glass) }
        } else {
            if prominent { content.buttonStyle(.borderedProminent) }
            else { content.buttonStyle(.bordered) }
        }
    }
}
struct StudioGlassControls<Content: View>: View {
    @ViewBuilder var content: () -> Content
    @ViewBuilder var body: some View {
        if #available(macOS 26.0, *) { GlassEffectContainer(spacing: 8) { content() } }
        else { content() }
    }
}
struct StudioGlassIcon: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @ViewBuilder func body(content: Content) -> some View {
        if #available(macOS 26.0, *), !reduceTransparency, contrast != .increased {
            content.buttonStyle(.plain).frame(width: 30, height: 30)
                .glassEffect(.regular.interactive(), in: .circle)
        } else { content.buttonStyle(.bordered).frame(minWidth: 30, minHeight: 30) }
    }
}
extension View {
    func studioGlassButton(prominent: Bool = false) -> some View { modifier(StudioGlassButton(prominent: prominent)) }
    func studioGlassIcon() -> some View { modifier(StudioGlassIcon()) }
}
