import SwiftUI

struct CalcView: View {
    @ObservedObject var state: CalcState
    let onDismiss: () -> Void

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
            tapeView
            separator
            inputLine
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

            Text(state.tape.isEmpty
                 ? "NO TAPE"
                 : "\(state.tape.count) ON TAPE")
                .font(.custom(arcadeFont, size: 11).bold())
                .foregroundColor(accent)
                .tracking(1)

            CloseButton(action: onDismiss, isActive: isActive)
                .padding(.leading, 12)
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

            Text(state.expression + (cursorOn && fieldLive ? "_" : " "))
                .font(.custom(arcadeFont, size: 15).bold())
                .foregroundColor(fieldLive ? .white : Color(white: 0.55))
                .lineLimit(1)
                .truncationMode(.head)

            Spacer(minLength: 12)

            resultText
        }
        .padding(.horizontal, 14)
        .frame(height: CalcLayout.inputHeight)
        .background(fieldLive ? Arcade.rowGlow : Color.clear)
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
            if state.focus == .field {
                Text("ENTER KEEP · ↑↓ HISTORY · ⌫ CLEAR · ESC QUIT")
            } else {
                Text("ENTER INSERT VALUE · ↑↓ MOVE · ESC BACK")
            }
        }
        .font(.custom(arcadeFont, size: 9).bold())
        .foregroundColor(isActive ? Arcade.dimText : Arcade.dimText.opacity(0.5))
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

private struct CloseButton: View {
    let action: () -> Void
    let isActive: Bool

    @State private var isHovering = false

    private var tint: Color {
        if isHovering { return Arcade.yellow }
        return isActive ? Arcade.pink : Arcade.dimText
    }

    var body: some View {
        Button(action: action) {
            Text("✕")
                .font(.custom(arcadeFont, size: 12).bold())
                .foregroundColor(tint)
                .shadow(color: isActive || isHovering ? tint.opacity(0.8) : .clear, radius: 4)
                .frame(width: 18, height: 18)
                .overlay(Rectangle().stroke(isHovering ? Arcade.yellow : tint.opacity(0.5), lineWidth: 1))
                // The panel is draggable by its background; give the button a solid hit area.
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help("Close (Esc)")
        .accessibilityLabel("Close")
    }
}

#if DEBUG
private func previewState(expression: String,
                          focus: CalcFocus = .field,
                          isKey: Bool = true,
                          entries: Int = 3) -> CalcState {
    let s = CalcState()
    s.expression = expression
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
