import AppKit
import SwiftUI

// Generates the app icon at every size the asset catalog needs.
//
// The icon is code, not a checked-in binary with no provenance: it uses the app's own
// palette, so it cannot drift from the UI, and any size can be regenerated at will.
//
//   ./Tools/render-icon.sh
//
// Every dimension is a fraction of `s`, so a 16pt icon is drawn at 16pt rather than being
// a downscale of the 512pt one — which is where small-size legibility is actually decided.

let bg     = Color(red: 0.031, green: 0.031, blue: 0.047)
let green  = Color(red: 0.239, green: 1.0,   blue: 0.620)

/// Dark squircle, neon rim, scanlines. Clip-9's icon shares this shell in pink; the
/// family resemblance lives here, and the glyph carries the meaning.
struct IconShell<Content: View>: View {
    let s: CGFloat
    let accent: Color
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: s * 0.2237, style: .continuous).fill(bg)

            content

            // Proportional, so it thins out gracefully instead of moiréing when small.
            VStack(spacing: s / 22) {
                ForEach(0..<22, id: \.self) { _ in
                    Rectangle().fill(Color.black.opacity(0.22)).frame(height: s / 44)
                }
            }
            .allowsHitTesting(false)

            RoundedRectangle(cornerRadius: s * 0.2237, style: .continuous)
                .strokeBorder(accent, lineWidth: max(1, s * 0.028))
                .shadow(color: accent.opacity(0.9), radius: s * 0.05)
        }
        .frame(width: s, height: s)
        .clipShape(RoundedRectangle(cornerRadius: s * 0.2237, style: .continuous))
    }
}

struct Calc9Icon: View {
    let s: CGFloat
    var body: some View {
        IconShell(s: s, accent: green) {
            Text("=")
                .font(.system(size: s * 0.62, weight: .bold, design: .monospaced))
                .foregroundColor(green)
                .shadow(color: green.opacity(0.9), radius: s * 0.06)
                .offset(y: -s * 0.03)
        }
    }
}

/// macOS asset catalog sizes: each logical size at 1x and 2x.
let sizes: [(name: String, px: CGFloat)] = [
    ("16",  16), ("16@2x",  32),
    ("32",  32), ("32@2x",  64),
    ("128", 128), ("128@2x", 256),
    ("256", 256), ("256@2x", 512),
    ("512", 512), ("512@2x", 1024),
]

@MainActor
func renderIcons() {
    let app = NSApplication.shared
    app.setActivationPolicy(.prohibited)

    let out = CommandLine.arguments.count > 1
        ? CommandLine.arguments[1]
        : "Sources/Assets.xcassets/AppIcon.appiconset"
    try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)

    for (name, px) in sizes {
        let r = ImageRenderer(content: Calc9Icon(s: px).frame(width: px, height: px))
        r.scale = 1                       // drawn at native size, never downscaled
        r.isOpaque = false
        guard let img = r.cgImage,
              let data = NSBitmapImageRep(cgImage: img)
                .representation(using: .png, properties: [:]) else {
            print("  ✗ icon-\(name).png"); continue
        }
        FileManager.default.createFile(atPath: "\(out)/icon-\(name).png", contents: data)
        print("  ✓ icon-\(name).png  (\(Int(px))px)")
    }
}

MainActor.assumeIsolated { renderIcons() }
