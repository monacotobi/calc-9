import SwiftUI

/// Everything Calc-9 can do, in one place.
///
/// This is data rather than a hand-laid-out view so `CalcLayout.helpContentHeight` can be
/// derived from it. Adding a row here resizes the sheet automatically.
enum HelpContent {

    struct Row: Identifiable {
        let id = UUID()
        let symbol: String
        let detail: String
        var tint: Color = Arcade.cyan
    }

    struct Section: Identifiable {
        let id = UUID()
        let title: String
        let rows: [Row]
    }

    static let sections: [Section] = [
        Section(title: "OPERATORS", rows: [
            Row(symbol: "+ - * /",  detail: "add, subtract, multiply, divide", tint: Arcade.pink),
            Row(symbol: "^  or  **", detail: "power    2^10 = 1,024", tint: Arcade.pink),
            Row(symbol: "%",        detail: "divide by 100    100+10% = 100.1", tint: Arcade.pink),
            Row(symbol: "( )",      detail: "grouping    (2+3)*4 = 20", tint: Arcade.pink),
            Row(symbol: "-x",       detail: "negate    -2^2 = -4, (-2)^2 = 4", tint: Arcade.pink),
        ]),
        Section(title: "FUNCTIONS — parentheses required", rows: [
            Row(symbol: "sqrt( )",  detail: "square root    sqrt(9) = 3"),
            Row(symbol: "abs( )",   detail: "absolute value    abs(-5) = 5"),
            Row(symbol: "ln( )",    detail: "natural log"),
            Row(symbol: "log( )",   detail: "log base 10    log(1000) = 3"),
            Row(symbol: "round( )", detail: "nearest whole number"),
            Row(symbol: "floor( )", detail: "round down"),
            Row(symbol: "ceil( )",  detail: "round up"),
        ]),
        Section(title: "CONSTANTS", rows: [
            Row(symbol: "pi", detail: "3.14159265…", tint: Arcade.yellow),
            Row(symbol: "e",  detail: "2.71828182…", tint: Arcade.yellow),
        ]),
        Section(title: "KEYS", rows: [
            Row(symbol: "Enter", detail: "compute, copy, and paste into the last app", tint: Arcade.result),
            Row(symbol: "↑ ↓",   detail: "browse the tape; Enter inserts that result", tint: Arcade.result),
            Row(symbol: "← →",   detail: "move the cursor; ⌘ jumps to start or end", tint: Arcade.result),
            Row(symbol: "⌫",     detail: "delete a character; ⌘⌫ clears everything", tint: Arcade.result),
            Row(symbol: "Esc",   detail: "close the panel", tint: Arcade.result),
        ]),
    ]
}

struct HelpView: View {
    let isActive: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(HelpContent.sections) { section in
                Text(section.title)
                    .font(.custom(arcadeFont, size: 10).bold())
                    .foregroundColor(isActive ? Arcade.pink : Arcade.dimText)
                    .tracking(2)
                    .frame(height: CalcLayout.helpSectionHeaderHeight, alignment: .bottom)

                ForEach(section.rows) { row in
                    HStack(spacing: 0) {
                        Text(row.symbol)
                            .font(.custom(arcadeFont, size: 11).bold())
                            .foregroundColor(isActive ? row.tint : Arcade.dimText)
                            .frame(width: 92, alignment: .leading)

                        Text(row.detail)
                            .font(.custom(arcadeFont, size: 11))
                            .foregroundColor(isActive ? Arcade.hintText : Arcade.dimText)
                            .lineLimit(1)

                        Spacer(minLength: 0)
                    }
                    .frame(height: CalcLayout.helpRowHeight)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, CalcLayout.helpVerticalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
