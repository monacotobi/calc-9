import Foundation

/// The engine's public surface. Everything the UI needs, and nothing about AppKit.
public enum Engine {

    /// Full evaluation. Throws on anything wrong — used when the user presses Enter and
    /// has asserted the expression is finished.
    public static func evaluate(_ input: String) throws -> Double {
        let tokens = try Tokenizer.tokenize(input)
        guard !tokens.isEmpty else { throw EngineError.incompleteExpression }
        return try Evaluator.evaluate(rpn: try Parser.toRPN(tokens))
    }

    /// The value shown live while typing.
    ///
    /// Most keystrokes leave the expression incomplete — `44*12+` is not valid — so
    /// evaluating strictly would blank the field on every operator and make it strobe.
    /// Instead this returns the value of the **longest valid prefix**: `44*12+` shows 528.
    ///
    /// Returns nil when no prefix evaluates, including on division by zero. Errors belong
    /// to Enter, not to typing.
    public static func livePreview(of input: String) -> Double? {
        var chars = Array(input)

        while !chars.isEmpty {
            do {
                return try evaluate(String(chars))
            } catch EngineError.divisionByZero {
                // Complete enough to evaluate, but the arithmetic is invalid. Falling back
                // to a shorter prefix here would print the value of "1" while the screen
                // reads "1/0" — worse than showing nothing.
                return nil
            } catch {
                // Syntactically incomplete: drop a character and try the shorter prefix.
                chars.removeLast()
            }
        }
        return nil
    }

    /// Display formatting: thousands separators, trimmed trailing zeros, and scientific
    /// notation once a number stops being readable.
    public static func format(_ value: Double) -> String {
        guard value.isFinite else { return "∞" }

        let magnitude = abs(value)
        if magnitude != 0, magnitude >= 1e16 || magnitude < 1e-6 {
            let f = NumberFormatter()
            f.numberStyle = .scientific
            f.maximumSignificantDigits = 10
            f.exponentSymbol = "e"
            return f.string(from: NSNumber(value: value)) ?? "\(value)"
        }

        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = ","
        f.decimalSeparator = "."
        f.usesGroupingSeparator = true
        f.maximumFractionDigits = 10   // trailing zeros are dropped by the formatter
        f.minimumFractionDigits = 0
        return f.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}
