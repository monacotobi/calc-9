import SwiftUI

/// Palette. Copied from Clip-9 rather than shared — the two apps are separate projects,
/// so a change here does not reach Clip-9 and vice versa.
///
/// **Calc-9 is green where Clip-9 is pink.** The two apps sit side by side in the menu bar
/// and in the Accessibility list, so they need to be distinguishable at a glance rather
/// than only by their icon glyph.
enum Arcade {
    static let bg       = Color(red: 0.031, green: 0.031, blue: 0.047)  // #080812
    static let green    = Color(red: 0.239, green: 1.0,   blue: 0.620)  // #3DFF9E
    static let cyan     = Color(red: 0.0,   green: 0.898, blue: 1.0)    // #00E5FF
    static let yellow   = Color(red: 1.0,   green: 0.902, blue: 0.0)    // #FFE600
    static let dimText  = Color(red: 0.267, green: 0.267, blue: 0.333)  // #444455

    /// Borders, separators, prompt, caret, selection. Clip-9 uses pink here.
    static let accent   = green

    /// The answer. It cannot also be `accent`, or it would stop standing out the moment
    /// the chrome went green.
    static let result   = yellow

    /// Errors share the result's slot on screen, so they must not share its colour.
    static let error    = Color(red: 1.0, green: 0.36, blue: 0.42)  // #FF5C6B

    static let rowGlow   = green.opacity(0.07)
    static let inertGlow = Color(red: 0.267, green: 0.267, blue: 0.333).opacity(0.14)

    /// Footer hints and help text. `dimText` on `bg` is roughly 2:1 contrast — fine as
    /// decoration, unreadable as instructions.
    static let hintText = Color(white: 0.92)
}

let arcadeFont = "Courier New"

/// Single source of truth for panel geometry.
///
/// `CalcWindow` sizes the panel before SwiftUI lays anything out, so it must predict the
/// content height. Clip-9 learned the hard way what happens when these numbers live in two
/// places: keep every layout constant here.
enum CalcLayout {
    static let width: CGFloat = 420
    static let outerPadding: CGFloat = 8

    static let headerHeight: CGFloat = 46
    static let separatorHeight: CGFloat = 5
    static let tapeRowHeight: CGFloat = 32
    static let inputHeight: CGFloat = 48
    static let footerHeight: CGFloat = 28

    /// The tape always renders `capacity` rows, blank ones included, so the panel never
    /// resizes as entries accumulate.
    static let tapeCapacity = 3

    static var contentHeight: CGFloat {
        headerHeight
            + separatorHeight
            + CGFloat(tapeCapacity) * tapeRowHeight
            + separatorHeight
            + inputHeight
            + separatorHeight
            + footerHeight
    }

    // MARK: Help sheet

    static let helpRowHeight: CGFloat = 19
    static let helpSectionHeaderHeight: CGFloat = 24
    static let helpVerticalPadding: CGFloat = 10

    /// Derived from the content so the two can never drift apart.
    static var helpContentHeight: CGFloat {
        let rows = HelpContent.sections.reduce(0) { $0 + $1.rows.count }
        let body = CGFloat(rows) * helpRowHeight
            + CGFloat(HelpContent.sections.count) * helpSectionHeaderHeight
            + helpVerticalPadding * 2
        return headerHeight + separatorHeight + body + separatorHeight + footerHeight
    }
}
