import AppKit
import SwiftUI

// Renders the REAL SwiftUI views to PNGs for the README.
//
// Not mockups: this imports CalcView and friends and draws them with ImageRenderer, so
// what ends up in docs/ is the same code that ships. Re-run it whenever the UI changes
// and the README can never quietly go stale.
//
//   ./Tools/render-screenshots.sh
//
// ImageRenderer draws the view, not the window, so the panel's drop shadow and rounded
// mask are reproduced here rather than captured.

@main
@MainActor
struct RenderScreenshots {

    static let scale: CGFloat = 2.0

    static func main() {
        // AppKit must exist before SwiftUI will rasterise text.
        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)

        let outputDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "docs"
        try? FileManager.default.createDirectory(atPath: outputDir,
                                                 withIntermediateDirectories: true)

        var failures = 0
        for shot in shots {
            let ok = render(shot.view, to: "\(outputDir)/\(shot.name).png", height: shot.height)
            print(ok ? "  ✓ \(shot.name).png" : "  ✗ \(shot.name).png FAILED")
            if !ok { failures += 1 }
        }

        print(failures == 0 ? "All screenshots rendered." : "\(failures) failed.")
        exit(failures == 0 ? 0 : 1)
    }

    // MARK: - The shots

    struct Shot {
        let name: String
        let height: CGFloat
        let view: AnyView
    }

    static var shots: [Shot] {
        [
            Shot(name: "calc-9", height: CalcLayout.contentHeight,
                 view: AnyView(CalcView(state: state(expression: "44*12+16", caret: 8),
                                        onDismiss: {}))),

            Shot(name: "calc-9-tape", height: CalcLayout.contentHeight,
                 view: AnyView(CalcView(state: state(expression: "600/",
                                                     focus: .tape(index: 1)),
                                        onDismiss: {}))),

            Shot(name: "calc-9-help", height: CalcLayout.helpContentHeight,
                 view: AnyView(CalcView(state: state(expression: "sqrt(2)", showingHelp: true),
                                        onDismiss: {}))),
        ]
    }

    /// Fixed sample data, so re-running produces byte-identical images unless the UI
    /// actually changed.
    static func state(expression: String,
                      caret: Int? = nil,
                      focus: CalcFocus = .field,
                      showingHelp: Bool = false) -> CalcState {
        let s = CalcState()
        s.tape.add(expression: "1920/16", value: 120)
        s.tape.add(expression: "sqrt(2)", value: 2.0.squareRoot())
        s.tape.add(expression: "(120+80)*3", value: 600)
        s.buffer = ExpressionBuffer(text: expression, caret: caret)
        s.focus = focus
        s.showingHelp = showingHelp
        return s
    }

    // MARK: - Rendering

    static func render(_ content: AnyView, to path: String, height: CGFloat) -> Bool {
        // Mirrors CalcWindow: outer padding, near-black backing, rounded mask — plus a
        // backdrop so the neon glow has something to bleed onto.
        let framed = content
            .frame(width: CalcLayout.width, height: height)
            .padding(CalcLayout.outerPadding)
            .background(Color.black.opacity(0.98))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: .black.opacity(0.6), radius: 24, y: 8)
            .padding(34)
            .background(
                LinearGradient(colors: [Color(white: 0.055), Color(white: 0.015)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            )

        let renderer = ImageRenderer(content: framed)
        renderer.scale = scale
        renderer.isOpaque = true

        guard let cgImage = renderer.cgImage else { return false }
        let rep = NSBitmapImageRep(cgImage: cgImage)
        guard let data = rep.representation(using: .png, properties: [:]) else { return false }
        return FileManager.default.createFile(atPath: path, contents: data)
    }
}
