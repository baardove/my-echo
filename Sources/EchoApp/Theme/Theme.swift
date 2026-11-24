import SwiftUI
import AppKit
import Observation
import EchoCore

enum AppThemeKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case neonCassette = "neon_cassette"
    case fiioNano = "fiio_nano"
    case fiioDisc = "fiio_disc"
    case winampClassic = "winamp_classic"
    case frostedGlass = "frosted_glass"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .neonCassette: return "Echo Cassette"
        case .fiioNano: return "Nano OLED"
        case .fiioDisc: return "Disc Metallic"
        case .winampClassic: return "Winamp 99 Classic"
        case .frostedGlass: return "Frosted Glass"
        }
    }

    var subtitle: String {
        switch self {
        case .neonCassette: return "FiiO / Snowsky Echo · 90s cyber-mint, arcade cyan & laser magenta"
        case .fiioNano: return "FiiO / Snowsky Nano · Matte obsidian CNC chassis, tangerine orange & 0.91\" OLED blue"
        case .fiioDisc: return "FiiO / Snowsky Disc · Brushed dark titanium, prismatic CD cyan & OLED amber"
        case .winampClassic: return "1999 Winamp 2.x · Gunmetal chassis, black LCD screen & phosphor green"
        case .frostedGlass: return "macOS Smoked Glass · Live frosted translucency, specular rims & crystal cassette"
        }
    }

    var brandTagline: String {
        switch self {
        case .neonCassette: return "ECHO · SIDE A DECK"
        case .fiioNano: return "NANO · 0.91\" OLED"
        case .fiioDisc: return "DISC · OPTICAL DECK"
        case .winampClassic: return "192 KBPS · 44 KHZ · STEREO"
        case .frostedGlass: return "CRYSTAL · GLASS DECK"
        }
    }
}

@MainActor
@Observable
final class ThemeManager {
    static let shared = ThemeManager()
    var kind: AppThemeKind = .neonCassette
}

@MainActor
enum EchoTheme {
    private static var kind: AppThemeKind { ThemeManager.shared.kind }

    static var isGlass: Bool { kind == .frostedGlass }

    // Surfaces
    static var canvas: Color {
        switch kind {
        case .neonCassette:  return Color(red: 0.035, green: 0.039, blue: 0.063) // #090A10
        case .fiioNano:      return Color(red: 0.035, green: 0.035, blue: 0.043) // #09090B matte jet OLED
        case .fiioDisc:      return Color(red: 0.055, green: 0.063, blue: 0.075) // #0E1013
        case .winampClassic: return Color(red: 0.055, green: 0.063, blue: 0.082) // #0E1015
        case .frostedGlass:  return Color(red: 0.045, green: 0.060, blue: 0.095).opacity(0.42)
        }
    }

    static var sidebar: Color {
        switch kind {
        case .neonCassette:  return Color(red: 0.047, green: 0.055, blue: 0.090) // #0C0E17
        case .fiioNano:      return Color(red: 0.055, green: 0.055, blue: 0.067) // #0E0E11 CNC aluminum
        case .fiioDisc:      return Color(red: 0.078, green: 0.086, blue: 0.102) // #14161A
        case .winampClassic: return Color(red: 0.110, green: 0.125, blue: 0.165) // #1C202A Winamp gunmetal
        case .frostedGlass:  return Color.white.opacity(0.045)
        }
    }

    static var surface: Color {
        switch kind {
        case .neonCassette:  return Color(red: 0.075, green: 0.086, blue: 0.133) // #131622
        case .fiioNano:      return Color(red: 0.086, green: 0.086, blue: 0.102) // #16161A
        case .fiioDisc:      return Color(red: 0.106, green: 0.118, blue: 0.141) // #1B1E24
        case .winampClassic: return Color(red: 0.082, green: 0.094, blue: 0.122) // #15181F LCD-panel chassis
        case .frostedGlass:  return Color.white.opacity(0.085)
        }
    }

    static var surfaceElevated: Color {
        switch kind {
        case .neonCassette:  return Color(red: 0.106, green: 0.122, blue: 0.184) // #1B1F2F
        case .fiioNano:      return Color(red: 0.125, green: 0.125, blue: 0.149) // #202026
        case .fiioDisc:      return Color(red: 0.149, green: 0.165, blue: 0.196) // #262A32 brushed titanium
        case .winampClassic: return Color(red: 0.145, green: 0.165, blue: 0.215) // #252A37 Winamp bevel
        case .frostedGlass:  return Color.white.opacity(0.145)
        }
    }

    static var playerBar: Color {
        switch kind {
        case .neonCassette:  return Color(red: 0.043, green: 0.047, blue: 0.078)
        case .fiioNano:      return Color(red: 0.027, green: 0.027, blue: 0.035) // Pure OLED bar
        case .fiioDisc:      return Color(red: 0.067, green: 0.075, blue: 0.090)
        case .winampClassic: return Color(red: 0.025, green: 0.035, blue: 0.025) // Classic dark Winamp LCD deck
        case .frostedGlass:  return Color(red: 0.055, green: 0.075, blue: 0.115).opacity(0.58)
        }
    }

    static var border: Color {
        switch kind {
        case .neonCassette:  return Color(red: 0.30, green: 0.85, blue: 1.0).opacity(0.16)
        case .fiioNano:      return Color(red: 1.00, green: 0.48, blue: 0.18).opacity(0.20)
        case .fiioDisc:      return Color(red: 0.72, green: 0.80, blue: 0.90).opacity(0.16)
        case .winampClassic: return Color(red: 0.45, green: 0.52, blue: 0.65).opacity(0.32)
        case .frostedGlass:  return Color.white.opacity(0.19)
        }
    }

    static var borderStrong: Color {
        switch kind {
        case .neonCassette:  return Color(red: 0.30, green: 0.85, blue: 1.0).opacity(0.30)
        case .fiioNano:      return Color(red: 1.00, green: 0.42, blue: 0.10).opacity(0.38)
        case .fiioDisc:      return Color(red: 0.78, green: 0.86, blue: 0.96).opacity(0.28)
        case .winampClassic: return Color(red: 0.00, green: 1.00, blue: 0.26).opacity(0.42)
        case .frostedGlass:  return Color.white.opacity(0.34)
        }
    }

    // Accents
    static var neoMint: Color {
        switch kind {
        case .neonCassette:  return Color(red: 0.078, green: 0.945, blue: 0.584) // #14F195 Electric Mint
        case .fiioNano:      return Color(red: 1.000, green: 0.420, blue: 0.102) // #FF6B1A Snowsky Tangerine Orange
        case .fiioDisc:      return Color(red: 0.310, green: 0.820, blue: 1.000) // #4FD1FF Prismatic CD Cyan
        case .winampClassic: return Color(red: 0.000, green: 1.000, blue: 0.255) // #00FF41 Phosphor LCD Green
        case .frostedGlass:  return Color(red: 0.420, green: 0.960, blue: 0.860) // #6BF5DB Crystal Prism Aqua
        }
    }

    static var neoCyan: Color {
        switch kind {
        case .neonCassette:  return Color(red: 0.000, green: 0.898, blue: 1.000) // #00E5FF Arcade Cyan
        case .fiioNano:      return Color(red: 0.220, green: 0.741, blue: 0.973) // #38BDF8 OLED Sky Blue
        case .fiioDisc:      return Color(red: 1.000, green: 0.620, blue: 0.173) // #FF9E2C Disc OLED Amber
        case .winampClassic: return Color(red: 1.000, green: 0.816, blue: 0.000) // #FFD000 Winamp VU Yellow
        case .frostedGlass:  return Color(red: 0.580, green: 0.880, blue: 1.000) // #94E0FF Glacial Ice Blue
        }
    }

    static var neoMagenta: Color {
        switch kind {
        case .neonCassette:  return Color(red: 1.000, green: 0.180, blue: 0.592) // #FF2E97 Laser Magenta
        case .fiioNano:      return Color(red: 1.000, green: 0.680, blue: 0.240) // #FFAD3D Warm Amber Highlight
        case .fiioDisc:      return Color(red: 0.660, green: 0.520, blue: 1.000) // #A885FF Optical Violet
        case .winampClassic: return Color(red: 1.000, green: 0.360, blue: 0.100) // #FF5C1A VU Peak Orange
        case .frostedGlass:  return Color(red: 0.820, green: 0.660, blue: 1.000) // #D1A8FF Prism Lilac
        }
    }

    static let neoViolet = Color(red: 0.659, green: 0.369, blue: 1.000)
    static let hiResGold = Color(red: 1.000, green: 0.722, blue: 0.180)
    static let warningAmber = Color(red: 1.000, green: 0.580, blue: 0.180)
    static let dangerCoral = Color(red: 1.000, green: 0.275, blue: 0.420)

    // Strict max-8px corner radius constants
    static var radiusCard: CGFloat { kind == .winampClassic ? 4 : 8 }
    static var radiusControl: CGFloat { kind == .winampClassic ? 3 : 6 }
    static var radiusSmall: CGFloat { kind == .winampClassic ? 2 : 4 }

    // Typography
    static var textPrimary: Color {
        switch kind {
        case .winampClassic: return Color(red: 0.88, green: 0.98, blue: 0.88)
        default:             return Color.white.opacity(0.95)
        }
    }

    static var textSecondary: Color {
        switch kind {
        case .winampClassic: return Color(red: 0.62, green: 0.78, blue: 0.66)
        default:             return Color.white.opacity(0.68)
        }
    }

    static var textMuted: Color {
        switch kind {
        case .winampClassic: return Color(red: 0.42, green: 0.54, blue: 0.48)
        default:             return Color.white.opacity(0.42)
        }
    }

    static var accentGradient: LinearGradient {
        LinearGradient(
            colors: [neoMint, neoCyan],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var retroNeonGradient: LinearGradient {
        LinearGradient(
            colors: [neoMagenta, neoViolet, neoCyan],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    static func color(for accent: DeviceAccentColor) -> Color {
        switch accent {
        case .mint: return Color(red: 0.078, green: 0.945, blue: 0.584)
        case .cyan: return Color(red: 0.000, green: 0.898, blue: 1.000)
        case .gold: return hiResGold
        case .violet: return neoViolet
        case .coral: return Color(red: 1.000, green: 0.180, blue: 0.592)
        case .blue: return Color(red: 0.25, green: 0.58, blue: 1.0)
        }
    }
}

/// Echo Brand Logo that adapts cleanly to the active theme (Cassette / FiiO Disc / Winamp Deck)
struct EchoBrandLogo: View {
    var size: CGFloat = 34
    var animate: Bool = false

    var body: some View {
        switch ThemeManager.shared.kind {
        case .neonCassette:
            EchoCassetteLogo(size: size, animateReels: animate)
        case .fiioNano:
            FiioNanoLogo(size: size)
        case .fiioDisc:
            FiioDiscLogo(size: size)
        case .winampClassic:
            WinampDeckLogo(size: size)
        case .frostedGlass:
            GlassCassetteLogo(size: size)
        }
    }
}

/// Real macOS frosted glass backdrop using NSVisualEffectView behindWindow blending
struct GlassWindowBackdrop: NSViewRepresentable {
    let isGlass: Bool

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        DispatchQueue.main.async {
            applyWindowStyle(view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.isHidden = !isGlass
        nsView.material = .hudWindow
        nsView.blendingMode = .behindWindow
        nsView.state = isGlass ? .active : .inactive
        DispatchQueue.main.async {
            applyWindowStyle(nsView.window)
        }
    }

    private func applyWindowStyle(_ window: NSWindow?) {
        guard let window else { return }
        if isGlass {
            window.isOpaque = false
            window.backgroundColor = .clear
        } else {
            window.isOpaque = true
            window.backgroundColor = NSColor(red: 0.04, green: 0.045, blue: 0.07, alpha: 1)
        }
    }
}

/// Translucent Crystal Glass Cassette Emblem for the Frosted Glass theme
struct GlassCassetteLogo: View {
    var size: CGFloat = 34

    var body: some View {
        let w = size * 1.38
        let h = size
        ZStack {
            RoundedRectangle(cornerRadius: min(6, h * 0.16), style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.24), Color.white.opacity(0.06)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: min(6, h * 0.16), style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.white.opacity(0.65), Color(red: 0.52, green: 0.88, blue: 1.0).opacity(0.45)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.2
                        )
                )

            VStack(spacing: h * 0.07) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.42, green: 0.96, blue: 0.86).opacity(0.75), Color(red: 0.58, green: 0.88, blue: 1.0).opacity(0.75)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: w * 0.78, height: h * 0.15)

                ZStack {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.black.opacity(0.35))
                        .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Color.white.opacity(0.35), lineWidth: 0.8))
                        .frame(width: w * 0.68, height: h * 0.34)

                    HStack(spacing: w * 0.22) {
                        Circle()
                            .strokeBorder(Color.white.opacity(0.9), lineWidth: 1.3)
                            .frame(width: h * 0.22, height: h * 0.22)
                        Circle()
                            .strokeBorder(Color(red: 0.42, green: 0.96, blue: 0.86), lineWidth: 1.3)
                            .frame(width: h * 0.22, height: h * 0.22)
                    }
                }

                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.white.opacity(0.38))
                    .frame(width: w * 0.36, height: max(2, h * 0.08))
            }
            .padding(.vertical, h * 0.08)
        }
        .frame(width: w, height: h)
        .shadow(color: Color(red: 0.52, green: 0.88, blue: 1.0).opacity(0.28), radius: 6, y: 1)
    }
}

/// FiiO Snowsky Echo Nano — horizontal CNC stick with 0.91" OLED & scroll wheel
struct FiioNanoLogo: View {
    var size: CGFloat = 34

    var body: some View {
        let w = size * 1.44
        let h = size * 0.86
        HStack(spacing: 1.5) {
            ZStack {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.16, green: 0.16, blue: 0.20), Color(red: 0.07, green: 0.07, blue: 0.09)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .strokeBorder(EchoTheme.neoMint.opacity(0.85), lineWidth: 1.2)
                    )

                // 0.91" OLED readout strip
                HStack(spacing: 3) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.black)
                        .overlay(
                            HStack(spacing: 1.5) {
                                Rectangle().fill(EchoTheme.neoCyan).frame(width: 2.5, height: h * 0.28)
                                Rectangle().fill(EchoTheme.neoCyan).frame(width: 2.5, height: h * 0.44)
                                Rectangle().fill(EchoTheme.neoMint).frame(width: 2.5, height: h * 0.34)
                                Rectangle().fill(EchoTheme.neoCyan).frame(width: 2.5, height: h * 0.22)
                            }
                        )
                        .frame(width: w * 0.62, height: h * 0.54)
                        .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(EchoTheme.neoCyan.opacity(0.45), lineWidth: 0.7))

                    Circle()
                        .fill(EchoTheme.neoMint)
                        .frame(width: h * 0.22, height: h * 0.22)
                }
            }
            .frame(width: w * 0.88, height: h)

            // Mechanical metal scroll wheel on side
            RoundedRectangle(cornerRadius: 2)
                .fill(EchoTheme.neoMint)
                .frame(width: max(3.5, w * 0.10), height: h * 0.62)
        }
        .frame(width: w, height: size)
        .shadow(color: EchoTheme.neoMint.opacity(0.32), radius: 5, y: 1)
    }
}

/// Echo Mini-inspired 90s Neon Retro Cassette Vector Logo
struct EchoCassetteLogo: View {
    var size: CGFloat = 34
    var animateReels: Bool = false
    @State private var spin = false

    var body: some View {
        let w = size * 1.38
        let h = size
        ZStack {
            RoundedRectangle(cornerRadius: min(6, h * 0.16), style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [EchoTheme.surfaceElevated, Color(red: 0.06, green: 0.07, blue: 0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: min(6, h * 0.16), style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [EchoTheme.neoCyan, EchoTheme.neoMagenta],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: max(1.2, h * 0.045)
                        )
                )

            VStack(spacing: h * 0.07) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(EchoTheme.retroNeonGradient)
                    .frame(width: w * 0.80, height: h * 0.17)

                ZStack {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Color.black.opacity(0.75))
                        .overlay(
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .strokeBorder(EchoTheme.neoMint.opacity(0.7), lineWidth: 0.9)
                        )
                        .frame(width: w * 0.68, height: h * 0.34)

                    Rectangle()
                        .fill(EchoTheme.neoMint.opacity(0.35))
                        .frame(width: w * 0.26, height: h * 0.12)

                    HStack(spacing: w * 0.22) {
                        cassetteReel(diameter: h * 0.22)
                        cassetteReel(diameter: h * 0.22)
                    }
                }

                HStack(spacing: w * 0.10) {
                    Circle().fill(EchoTheme.neoCyan.opacity(0.85)).frame(width: max(2, h * 0.07), height: max(2, h * 0.07))
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(EchoTheme.textMuted.opacity(0.5))
                        .frame(width: w * 0.28, height: max(2, h * 0.08))
                    Circle().fill(EchoTheme.neoMagenta.opacity(0.85)).frame(width: max(2, h * 0.07), height: max(2, h * 0.07))
                }
            }
            .padding(.vertical, h * 0.08)
        }
        .frame(width: w, height: h)
        .shadow(color: EchoTheme.neoCyan.opacity(0.28), radius: 5, y: 1)
        .onAppear {
            if animateReels {
                withAnimation(.linear(duration: 3.0).repeatForever(autoreverses: false)) {
                    spin = true
                }
            }
        }
    }

    private func cassetteReel(diameter: CGFloat) -> some View {
        ZStack {
            Circle()
                .strokeBorder(EchoTheme.neoMint, lineWidth: max(1, diameter * 0.16))
            Circle()
                .fill(EchoTheme.canvas)
                .frame(width: diameter * 0.45, height: diameter * 0.45)
            Rectangle()
                .fill(EchoTheme.neoMint)
                .frame(width: diameter * 0.72, height: max(0.8, diameter * 0.14))
                .rotationEffect(.degrees(spin ? 360 : 0))
        }
        .frame(width: diameter, height: diameter)
    }
}

/// FiiO Snowsky Disc-inspired Metallic Optical Discman Logo
struct FiioDiscLogo: View {
    var size: CGFloat = 34

    var body: some View {
        let w = size * 1.38
        let h = size
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.22, green: 0.25, blue: 0.30), Color(red: 0.08, green: 0.09, blue: 0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(EchoTheme.neoMint.opacity(0.6), lineWidth: 1.2)
                )

            HStack(spacing: 4) {
                // Circular 1.8" Disc screen + CD shimmer
                ZStack {
                    Circle()
                        .fill(
                            AngularGradient(
                                colors: [EchoTheme.neoMint, EchoTheme.neoViolet, EchoTheme.neoCyan, EchoTheme.neoMint],
                                center: .center
                            )
                        )
                        .frame(width: h * 0.74, height: h * 0.74)
                    Circle()
                        .fill(EchoTheme.canvas)
                        .frame(width: h * 0.28, height: h * 0.28)
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.6), lineWidth: 0.8))
                }
                VStack(spacing: 2.5) {
                    RoundedRectangle(cornerRadius: 1).fill(EchoTheme.neoCyan).frame(width: 5, height: 2.5)
                    RoundedRectangle(cornerRadius: 1).fill(Color.white.opacity(0.45)).frame(width: 5, height: 2.5)
                    RoundedRectangle(cornerRadius: 1).fill(Color.white.opacity(0.45)).frame(width: 5, height: 2.5)
                }
            }
        }
        .frame(width: w, height: h)
        .shadow(color: EchoTheme.neoMint.opacity(0.25), radius: 5, y: 1)
    }
}

/// Winamp 99 Classic Phosphor LCD + Spectrum Logo
struct WinampDeckLogo: View {
    var size: CGFloat = 34

    var body: some View {
        let w = size * 1.38
        let h = size
        ZStack {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(Color(red: 0.14, green: 0.16, blue: 0.22))
                .overlay(
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .strokeBorder(Color(red: 0.45, green: 0.52, blue: 0.65), lineWidth: 1.2)
                )

            // Inner black LCD window with green/yellow/orange spectrum bars
            HStack(alignment: .bottom, spacing: 2) {
                ForEach([0.45, 0.85, 0.65, 1.0, 0.55, 0.80, 0.38], id: \.self) { frac in
                    RoundedRectangle(cornerRadius: 0.8)
                        .fill(
                            LinearGradient(
                                colors: [EchoTheme.neoMagenta, EchoTheme.neoCyan, EchoTheme.neoMint],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: max(2, w * 0.08), height: max(3, h * 0.58 * frac))
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 3)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 2))
            .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(EchoTheme.neoMint.opacity(0.45), lineWidth: 0.8))
        }
        .frame(width: w, height: h)
    }
}

enum Formatters {
    static func duration(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite && seconds > 0 else { return "0:00" }
        let total = Int(seconds.rounded())
        let hrs = total / 3600
        let mins = (total % 3600) / 60
        let secs = total % 60
        if hrs > 0 {
            return String(format: "%d:%02d:%02d", hrs, mins, secs)
        }
        return String(format: "%d:%02d", mins, secs)
    }

    static func bytes(_ count: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: max(0, count), countStyle: .file)
    }
}

@MainActor
final class ArtworkImageLoader {
    static let shared = ArtworkImageLoader()
    private let imageCache = NSCache<NSString, NSImage>()
    private let colorCache = NSCache<NSString, NSColor>()

    init() {
        imageCache.countLimit = 400
        colorCache.countLimit = 400
    }

    func image(forHash hash: String?, artworkCache: ArtworkCache) -> NSImage? {
        guard let hash else { return nil }
        let key = hash as NSString
        if let cached = imageCache.object(forKey: key) {
            return cached
        }
        guard let data = artworkCache.loadThumbnailData(for: hash),
              let img = NSImage(data: data) else {
            return nil
        }
        imageCache.setObject(img, forKey: key)
        return img
    }

    func dominantColor(forHash hash: String?, artworkCache: ArtworkCache) -> Color {
        guard let hash else { return EchoTheme.neoViolet.opacity(0.45) }
        let key = hash as NSString
        if let cached = colorCache.object(forKey: key) {
            return Color(nsColor: cached)
        }
        guard let img = image(forHash: hash, artworkCache: artworkCache),
              let extracted = extractDominantColor(from: img) else {
            return EchoTheme.neoViolet.opacity(0.45)
        }
        colorCache.setObject(extracted, forKey: key)
        return Color(nsColor: extracted)
    }

    private func extractDominantColor(from image: NSImage) -> NSColor? {
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let size = 16
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var pixels = [UInt8](repeating: 0, count: size * size * 4)
        guard let ctx = CGContext(
            data: &pixels,
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: size * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: size, height: size))

        var rSum: Double = 0
        var gSum: Double = 0
        var bSum: Double = 0
        var weightSum: Double = 0

        for i in stride(from: 0, to: pixels.count, by: 4) {
            let r = Double(pixels[i]) / 255.0
            let g = Double(pixels[i + 1]) / 255.0
            let b = Double(pixels[i + 2]) / 255.0
            let maxC = max(r, max(g, b))
            let minC = min(r, min(g, b))
            let sat = maxC > 0 ? (maxC - minC) / maxC : 0
            let w = 0.2 + sat * 2.5 * (maxC > 0.15 ? 1.0 : 0.2)
            rSum += r * w
            gSum += g * w
            bSum += b * w
            weightSum += w
        }

        guard weightSum > 0 else { return nil }
        let avg = NSColor(
            calibratedRed: CGFloat(rSum / weightSum),
            green: CGFloat(gSum / weightSum),
            blue: CGFloat(bSum / weightSum),
            alpha: 1.0
        )
        var h: CGFloat = 0, s: CGFloat = 0, br: CGFloat = 0, a: CGFloat = 0
        avg.getHue(&h, saturation: &s, brightness: &br, alpha: &a)
        return NSColor(
            calibratedHue: h,
            saturation: min(0.92, max(0.45, s * 1.25)),
            brightness: min(0.78, max(0.35, br)),
            alpha: 1.0
        )
    }
}
