#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="$ROOT_DIR/build/My Echo.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "▶ Building My Echo (release)..."
cd "$ROOT_DIR"
swift build -c release

BIN_PATH="$(swift build -c release --show-bin-path)/Echo"

echo "▶ Packaging My Echo.app bundle..."
rm -rf "$APP_DIR" "$ROOT_DIR/build/Echo.app"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$BIN_PATH" "$MACOS_DIR/My Echo"

cat > "$CONTENTS_DIR/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleDisplayName</key>
    <string>My Echo</string>
    <key>CFBundleExecutable</key>
    <string>My Echo</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.myecho.audiomanager</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>My Echo</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.2.0</string>
    <key>CFBundleVersion</key>
    <string>3</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
</dict>
</plist>
EOF

# Generate 90s Neon Retro Echo Cassette AppIcon.icns using Swift CoreGraphics + iconutil
ICONSET_DIR="$ROOT_DIR/build/AppIcon.iconset"
rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"

swift - "$ICONSET_DIR" <<'SWIFT'
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let iconsetPath = CommandLine.arguments[1]

func renderCassetteIcon(px: Int) -> CGImage? {
    let cs = CGColorSpace(name: CGColorSpace.sRGB)!
    guard let ctx = CGContext(
        data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0,
        space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }

    let s = CGFloat(px)
    let cardInset = s * 0.07
    let cardRect = CGRect(x: cardInset, y: cardInset, width: s - cardInset * 2, height: s - cardInset * 2)
    let cardRadius = s * 0.14

    // Outer midnight obsidian shell
    let shellPath = CGPath(roundedRect: cardRect, cornerWidth: cardRadius, cornerHeight: cardRadius, transform: nil)
    ctx.saveGState()
    ctx.addPath(shellPath)
    ctx.clip()

    let bgColors = [
        CGColor(red: 0.04, green: 0.045, blue: 0.08, alpha: 1),
        CGColor(red: 0.10, green: 0.11, blue: 0.18, alpha: 1)
    ] as CFArray
    if let grad = CGGradient(colorsSpace: cs, colors: bgColors, locations: [0, 1]) {
        ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: s), end: CGPoint(x: s, y: 0), options: [])
    }

    // Subtle neon synth radial glow behind cassette
    let glowColors = [
        CGColor(red: 0.08, green: 0.94, blue: 0.58, alpha: 0.32),
        CGColor(red: 0.0, green: 0.90, blue: 1.0, alpha: 0.0)
    ] as CFArray
    if let rad = CGGradient(colorsSpace: cs, colors: glowColors, locations: [0, 1]) {
        ctx.drawRadialGradient(rad, startCenter: CGPoint(x: s * 0.5, y: s * 0.52), startRadius: 0,
                               endCenter: CGPoint(x: s * 0.5, y: s * 0.52), endRadius: s * 0.45, options: [])
    }
    ctx.restoreGState()

    // Neon rim border around icon tile
    ctx.addPath(shellPath)
    ctx.setStrokeColor(CGColor(red: 0.0, green: 0.90, blue: 1.0, alpha: 0.55))
    ctx.setLineWidth(max(1.5, s * 0.022))
    ctx.strokePath()

    // Cassette body inside tile (classic 1.54:1 cassette proportions)
    let cw = s * 0.72
    let ch = s * 0.48
    let cx = (s - cw) / 2
    let cy = (s - ch) / 2
    let cassRect = CGRect(x: cx, y: cy, width: cw, height: ch)
    let cassPath = CGPath(roundedRect: cassRect, cornerWidth: s * 0.045, cornerHeight: s * 0.045, transform: nil)

    ctx.setFillColor(CGColor(red: 0.08, green: 0.095, blue: 0.15, alpha: 1))
    ctx.addPath(cassPath)
    ctx.fillPath()
    ctx.setStrokeColor(CGColor(red: 1.0, green: 0.18, blue: 0.59, alpha: 0.9))
    ctx.setLineWidth(max(1.2, s * 0.018))
    ctx.addPath(cassPath)
    ctx.strokePath()

    // Top 90s Neon label stripe (magenta -> violet -> cyan)
    let stripeRect = CGRect(x: cx + cw * 0.08, y: cy + ch * 0.69, width: cw * 0.84, height: ch * 0.18)
    let stripePath = CGPath(roundedRect: stripeRect, cornerWidth: s * 0.015, cornerHeight: s * 0.015, transform: nil)
    ctx.saveGState()
    ctx.addPath(stripePath)
    ctx.clip()
    let stripeColors = [
        CGColor(red: 1.0, green: 0.18, blue: 0.59, alpha: 1),
        CGColor(red: 0.66, green: 0.37, blue: 1.0, alpha: 1),
        CGColor(red: 0.0, green: 0.90, blue: 1.0, alpha: 1)
    ] as CFArray
    if let sGrad = CGGradient(colorsSpace: cs, colors: stripeColors, locations: [0, 0.5, 1]) {
        ctx.drawLinearGradient(sGrad, start: CGPoint(x: stripeRect.minX, y: stripeRect.midY),
                               end: CGPoint(x: stripeRect.maxX, y: stripeRect.midY), options: [])
    }
    ctx.restoreGState()

    // Center dark tape window
    let winRect = CGRect(x: cx + cw * 0.14, y: cy + ch * 0.27, width: cw * 0.72, height: ch * 0.34)
    let winPath = CGPath(roundedRect: winRect, cornerWidth: s * 0.02, cornerHeight: s * 0.02, transform: nil)
    ctx.setFillColor(CGColor(red: 0.02, green: 0.025, blue: 0.04, alpha: 1))
    ctx.addPath(winPath)
    ctx.fillPath()
    ctx.setStrokeColor(CGColor(red: 0.08, green: 0.95, blue: 0.58, alpha: 0.8))
    ctx.setLineWidth(max(1.0, s * 0.012))
    ctx.addPath(winPath)
    ctx.strokePath()

    // Tape ribbon bridge
    ctx.setFillColor(CGColor(red: 0.08, green: 0.95, blue: 0.58, alpha: 0.32))
    ctx.fill(CGRect(x: winRect.midX - winRect.width * 0.18, y: winRect.midY - winRect.height * 0.20,
                    width: winRect.width * 0.36, height: winRect.height * 0.40))

    // Left & Right tape reels (electric mint)
    let reelR = winRect.height * 0.34
    for rx in [winRect.minX + winRect.width * 0.24, winRect.maxX - winRect.width * 0.24] {
        let ry = winRect.midY
        ctx.setStrokeColor(CGColor(red: 0.08, green: 0.95, blue: 0.58, alpha: 1))
        ctx.setLineWidth(max(1.2, s * 0.02))
        ctx.strokeEllipse(in: CGRect(x: rx - reelR, y: ry - reelR, width: reelR * 2, height: reelR * 2))
        // Reel hub spoke
        ctx.setFillColor(CGColor(red: 0.08, green: 0.95, blue: 0.58, alpha: 1))
        ctx.fill(CGRect(x: rx - reelR * 0.65, y: ry - max(0.8, s * 0.008), width: reelR * 1.3, height: max(1.6, s * 0.016)))
    }

    // Bottom cassette trapezoid & capstan holes
    let trapRect = CGRect(x: cx + cw * 0.22, y: cy + ch * 0.04, width: cw * 0.56, height: ch * 0.14)
    ctx.setFillColor(CGColor(red: 0.14, green: 0.17, blue: 0.26, alpha: 1))
    ctx.fill(trapRect)
    let holeR = max(1.2, s * 0.016)
    ctx.setFillColor(CGColor(red: 0.0, green: 0.90, blue: 1.0, alpha: 0.9))
    ctx.fillEllipse(in: CGRect(x: trapRect.minX + trapRect.width * 0.18 - holeR, y: trapRect.midY - holeR, width: holeR * 2, height: holeR * 2))
    ctx.setFillColor(CGColor(red: 1.0, green: 0.18, blue: 0.59, alpha: 0.9))
    ctx.fillEllipse(in: CGRect(x: trapRect.maxX - trapRect.width * 0.18 - holeR, y: trapRect.midY - holeR, width: holeR * 2, height: holeR * 2))

    return ctx.makeImage()
}

func savePNG(_ img: CGImage, to path: String) {
    let url = URL(fileURLWithPath: path)
    if let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) {
        CGImageDestinationAddImage(dest, img, nil)
        CGImageDestinationFinalize(dest)
    }
}

let pairs: [(Int, String)] = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png")
]

for (px, name) in pairs {
    if let img = renderCassetteIcon(px: px) {
        savePNG(img, to: "\(iconsetPath)/\(name)")
    }
}
SWIFT

iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES_DIR/AppIcon.icns"
rm -rf "$ICONSET_DIR"

echo "✅ Built $APP_DIR"
