import SwiftUI

/// Where the keyboard is pointing inside the panel.
enum CalcFocus: Equatable {
    /// Typing an expression. The default.
    case field
    /// Browsing the tape; `index` is the selected row, 0 = newest.
    case tape(index: Int)
}

/// Shared state between the NSPanel (which owns key handling) and SwiftUI (which renders).
///
/// All mutation happens on the main thread from `CalcWindow`.
final class CalcState: ObservableObject {

    @Published var expression: String = ""
    @Published var tape = Tape(capacity: CalcLayout.tapeCapacity)
    @Published var focus: CalcFocus = .field

    /// Set from NSPanel's becomeKey/resignKey. The panel is non-activating and stays open
    /// when you click away, so it can be visible while receiving no keys at all.
    @Published var isKey: Bool = true

    /// Shown on Enter when the expression will not evaluate. Cleared on the next keystroke.
    @Published var errorText: String?

    /// The value shown live to the right of the expression, or nil while nothing evaluates.
    var preview: Double? { Engine.livePreview(of: expression) }

    var selectedTapeIndex: Int? {
        if case .tape(let i) = focus { return i }
        return nil
    }

    // MARK: - Editing

    func type(_ s: String) {
        errorText = nil
        focus = .field
        expression.append(s)
    }

    func backspace() {
        errorText = nil
        guard !expression.isEmpty else { return }
        expression.removeLast()
    }

    func clear() {
        errorText = nil
        expression = ""
    }

    // MARK: - Tape navigation

    /// Up from the field enters the tape at the newest row; up inside the tape moves older.
    func moveUp() {
        guard !tape.isEmpty else { return }
        switch focus {
        case .field:
            focus = .tape(index: 0)
        case .tape(let i):
            focus = .tape(index: min(i + 1, tape.count - 1))
        }
    }

    /// Down moves toward newer, and off the bottom returns to the field.
    func moveDown() {
        switch focus {
        case .field:
            break
        case .tape(let i):
            focus = i == 0 ? .field : .tape(index: i - 1)
        }
    }

    /// Enter while browsing: insert the selected result and go back to typing.
    func insertSelectedResult() {
        guard case .tape(let i) = focus, let entry = tape[i] else { return }
        expression.append(Engine.format(entry.value).replacingOccurrences(of: ",", with: ""))
        focus = .field
    }

    // MARK: - Commit

    /// Evaluate, push onto the tape, and hand back the formatted result to copy and paste.
    /// Returns nil when the expression will not evaluate; `errorText` explains why.
    func commit() -> String? {
        guard !expression.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        do {
            let value = try Engine.evaluate(expression)
            tape.add(expression: expression, value: value)
            let formatted = Engine.format(value)
            expression = ""
            errorText = nil
            focus = .field
            return formatted
        } catch let error as EngineError {
            errorText = Self.message(for: error)
            return nil
        } catch {
            errorText = "ERR"
            return nil
        }
    }

    private static func message(for error: EngineError) -> String {
        switch error {
        case .divisionByZero:            return "ERR — DIV BY ZERO"
        case .unbalancedParentheses:     return "ERR — PARENTHESES"
        case .incompleteExpression:      return "ERR — INCOMPLETE"
        case .malformedNumber(let s):    return "ERR — BAD NUMBER \(s)"
        case .unexpectedCharacter(let c): return "ERR — BAD CHAR \(c)"
        }
    }
}
