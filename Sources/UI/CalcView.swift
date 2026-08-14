import SwiftUI

struct CalcView: View {
    @ObservedObject var state: CalcState
    let onDismiss: () -> Void
    var onToggleHelp: () -> Void = {}

    @State private var cursorOn = true
    private let blinker = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    /// True when the panel has the keyboard. When false the neon goes out — same treatment
    /// as Clip-9's picker, built in from the start here rather than retrofitted.
    private var isActive: Bool { state.isKey }
    private var accent: Color { isActive ? Arcade.pink : Arcade.dimText }

    /// The expression field is "live" only when the panel has keys AND focus is not in the
    /// tape. Browsing the tape dims the field using the same language.
    private var fieldLive: Bool { isActive && state.focus == .field }

    var body: some View {
        VStack(spacing: 0) {
            header
            separator
            if state.showingHelp {
                HelpView(isActive: isActive)
            } else {
                tapeView
                separator
                inputLine
            }
            separator
            footer
        }
        .background(Arcade.bg)
        .cornerRadius(4)
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(accent, lineWidth: 1.5))
        .shadow(color: isActive ? Arcade.pink.opacity(0.45) : .clear, radius: 12)
        .shadow(color: isActive ? Arcade.pink.opacity(0.2)  : .clear, radius: 28)
        .animation(.easeInOut(duration: 0.12), value: isActive)
        .animation(.easeInOut(duration: 0.08), value: state.focus)
        .onReceive(blinker) { _ in
            // Frozen cursor when the panel is not listening, or when focus is in the tape.
            cursorOn = fieldLive ? !cursorOn : true
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 0) {
            Text("🔢 CALC-9")
                .font(.custom(arcadeFont, size: 13).bold())
                .foregroundColor(isActive ? Arcade.cyan : Arcade.cyan.opacity(0.3))
                .tracking(3)
                .shadow(color: isActive ? Arcade.cyan.opacity(0.8) : .clear, radius: 6)

            Spacer()

            if !state.showingHelp {
                Text(state.tape.isEmpty
                     ? "NO TAPE"
                     : "\(state.tape.count) ON TAPE")
                    .font(.custom(arcadeFont, size: 11).bold())
                    .foregroundColor(accent)
                    .tracking(1)
            }

            HeaderButton(glyph: "i", action: onToggleHelp,
                         isActive: isActive, isOn: state.showingHelp)
                .padding(.leading, 12)

            HeaderButton(glyph: "✕", action: onDismiss, isActive: isActive)
                .padding(.leading, 6)
        }
        .padding(.horizontal, 14)
        .frame(height: CalcLayout.headerHeight)
    }

    private var separator: some View {
        VStack(spacing: 2) {
            Rectangle().fill(accent).frame(height: 1)
            Rectangle().fill(accent.opacity(0.35)).frame(height: 1)
        }
        .frame(height: CalcLayout.separatorHeight)
        .shadow(color: isActive ? Arcade.pink.opacity(0.6) : .clear, radius: 4)
    }

    // MARK: Tape

    /// Always renders `tapeCapacity` rows, padding with blanks, so the panel height is
    /// constant and nothing shifts as entries accumulate.
    private var tapeView: some View {
        VStack(spacing: 0) {
            ForEach(0..<CalcLayout.tapeCapacity, id: \.self) { slot in
                // Oldest at top, newest just above the input line.
                let index = CalcLayout.tapeCapacity - 1 - slot
                TapeRow(
                    entry: state.tape[index],
                    isSelected: state.selectedTapeIndex == index,
                    isActive: isActive
                )
            }
        }
    }

    // MARK: Input

    private var inputLine: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(">")
                .font(.custom(arcadeFont, size: 15).bold())
                .foregroundColor(fieldLive ? Arcade.pink : Arcade.dimText)
                .shadow(color: fieldLive ? Arcade.pink.opacity(0.8) : .clear, radius: 6)
                .padding(.trailing, 10)

            expressionText
                .font(.custom(arcadeFont, size: 15).bold())
                .lineLimit(1)
                .truncationMode(.head)

            Spacer(minLength: 12)

            resultText
        }
        .padding(.horizontal, 14)
        .frame(height: CalcLayout.inputHeight)
        .background(fieldLive ? Arcade.rowGlow : Color.clear)
    }

    /// The expression split around the caret, so the block cursor can sit mid-string.
    ///
    /// The caret glyph blinks between "▌" and a space rather than appearing and vanishing:
    /// in a monospaced font both are one cell wide, so the text either side never shifts.
    private var expressionText: Text {
        let ink = fieldLive ? Color.white : Color(white: 0.55)
        return Text(state.buffer.before).foregroundColor(ink)
            + Text(cursorOn && fieldLive ? "▌" : " ")
                .foregroundColor(Arcade.pink)
            + Text(state.buffer.after).foregroundColor(ink)
    }

    @ViewBuilder
    private var resultText: some View {
        if let error = state.errorText {
            Text(error)
                .font(.custom(arcadeFont, size: 11).bold())
                .foregroundColor(Arcade.yellow)
                .shadow(color: Arcade.yellow.opacity(0.6), radius: 5)
                .lineLimit(1)
        } else if let preview = state.preview {
            Text(Engine.format(preview))
                .font(.custom(arcadeFont, size: 15).bold())
                .foregroundColor(isActive ? Arcade.result : Arcade.result.opacity(0.35))
                .shadow(color: isActive ? Arcade.result.opacity(0.6) : .clear, radius: 8)
                .lineLimit(1)
        }
    }

    // MARK: Footer

    private var footer: some View {
        HStack {
            if state.showingHelp {
                Text("ESC or ? TO GO BACK")
            } else if state.focus == .field {
                Text("ENTER KEEP · ↑↓ TAPE · ←→ MOVE · ? HELP · ESC QUIT")
            } else {
                Text("ENTER INSERT VALUE · ↑↓ MOVE · ESC BACK")
            }
        }
        // Bumped from 9pt dimText: that was ~2:1 contrast on this background, which reads
        // as decoration rather than instructions.
        .font(.custom(arcadeFont, size: 10).bold())
        .foregroundColor(isActive ? Arcade.hintText : Arcade.hintText.opacity(0.35))
        .tracking(1)
        .frame(height: CalcLayout.footerHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
    }
}

// MARK: - Tape row

private struct TapeRow: View {
    let entry: TapeEntry?
    let isSelected: Bool
    let isActive: Bool

    private var accent: Color { isActive ? Arcade.pink : Arcade.dimText }

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(isSelected ? accent : Color.clear)
                .frame(width: 3)
                .shadow(color: isSelected && isActive ? Arcade.pink.opacity(0.9) : .clear, radius: 4)

            HStack(spacing: 0) {
                Text(isSelected ? "►" : " ")
                    .font(.custom(arcadeFont, size: 12).bold())
                    .foregroundColor(accent)
                    .shadow(color: isSelected && isActive ? Arcade.pink.opacity(0.8) : .clear, radius: 4)
                    .frame(width: 16)

                if let entry {
                    Text(entry.expression)
                        .font(.custom(arcadeFont, size: 12).bold())
                        .foregroundColor(expressionColor)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Text(" = ")
                        .font(.custom(arcadeFont, size: 12).bold())
                        .foregroundColor(Arcade.dimText)

                    Spacer(minLength: 8)

                    Text(Engine.format(entry.value))
                        .font(.custom(arcadeFont, size: 12).bold())
                        .foregroundColor(valueColor)
                        .shadow(color: isSelected && isActive ? Arcade.result.opacity(0.5) : .clear, radius: 5)
                        .lineLimit(1)
                } else {
                    Spacer()
                }
            }
            .padding(.horizontal, 10)
        }
        .frame(height: CalcLayout.tapeRowHeight)
        .background(isSelected ? (isActive ? Arcade.rowGlow : Arcade.inertGlow) : Color.clear)
    }

    private var expressionColor: Color {
        if isSelected { return isActive ? .white : Color(white: 0.6) }
        return Arcade.dimText
    }

    private var valueColor: Color {
        if isSelected { return isActive ? Arcade.result : Arcade.result.opacity(0.4) }
        return isActive ? Arcade.result.opacity(0.55) : Arcade.result.opacity(0.25)
    }
}

// MARK: - Close button

private struct HeaderButton: View {
    let glyph: String
    let action: () -> Void
    let isActive: Bool
    var isOn: Bool = false

    @State private var isHovering = false

    private var tint: Color {
        if isHovering || isOn { return Arcade.yellow }
        return isActive ? Arcade.pink : Arcade.dimText
    }

    var body: some View {
        Button(action: action) {
            Text(glyph)
                .font(.custom(arcadeFont, size: 12).bold())
                .foregroundColor(tint)
                .shadow(color: isActive || isHovering ? tint.opacity(0.8) : .clear, radius: 4)
                .frame(width: 18, height: 18)
                .overlay(Rectangle().stroke(isHovering || isOn ? Arcade.yellow : tint.opacity(0.5),
                                            lineWidth: 1))
                // The panel is draggable by its background; give the button a solid hit area.
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help(glyph == "i" ? "What Calc-9 can do" : "Close (Esc)")
        .accessibilityLabel(glyph == "i" ? "Help" : "Close")
    }
}

#if DEBUG
private func previewState(expression: String,
                          caret: Int? = nil,
                          focus: CalcFocus = .field,
                          isKey: Bool = true,
                          entries: Int = 3) -> CalcState {
    let s = CalcState()
    s.buffer = ExpressionBuffer(text: expression, caret: caret)
    s.focus = focus
    s.isKey = isKey
    let samples = [("1920/16", 120.0), ("0.15*89.90", 13.485), ("(120+80)*3", 600.0)]
    for (e, v) in samples.prefix(entries) { s.tape.add(expression: e, value: v) }
    return s
}

#Preview("Typing") {
    CalcView(state: previewState(expression: "44*12+"), onDismiss: {})
        .frame(width: CalcLayout.width, height: CalcLayout.contentHeight)
        .padding(20).background(Color.black)
}

// Caret parked mid-expression after arrowing left.
#Preview("Caret in the middle") {
    CalcView(state: previewState(expression: "44*12+16", caret: 4), onDismiss: {})
        .frame(width: CalcLayout.width, height: CalcLayout.contentHeight)
        .padding(20).background(Color.black)
}

#Preview("Browsing tape") {
    CalcView(state: previewState(expression: "44*12+", focus: .tape(index: 1)), onDismiss: {})
        .frame(width: CalcLayout.width, height: CalcLayout.contentHeight)
        .padding(20).background(Color.black)
}

#Preview("Empty") {
    CalcView(state: previewState(expression: "", entries: 0), onDismiss: {})
        .frame(width: CalcLayout.width, height: CalcLayout.contentHeight)
        .padding(20).background(Color.black)
}

#Preview("Not focused") {
    CalcView(state: previewState(expression: "44*12", isKey: false), onDismiss: {})
        .frame(width: CalcLayout.width, height: CalcLayout.contentHeight)
        .padding(20).background(Color.black)
}

#Preview("Error") {
    let s = previewState(expression: "1/0")
    s.errorText = "ERR — DIV BY ZERO"
    return CalcView(state: s, onDismiss: {})
        .frame(width: CalcLayout.width, height: CalcLayout.contentHeight)
        .padding(20).background(Color.black)
}
#endif
