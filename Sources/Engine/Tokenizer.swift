import Foundation

/// Anything that can go wrong turning text into a number.
public enum EngineError: Error, Equatable {
    case unexpectedCharacter(Character)
    case malformedNumber(String)
    case unbalancedParentheses
    case incompleteExpression
    case divisionByZero
    case unknownIdentifier(String)
    case expectedParenthesis(String)
    /// Defined mathematically, but not over the reals — sqrt(-1), ln(0).
    case mathDomain(String)
}

/// Single-argument functions, applied by name.
public enum MathFunction: String, CaseIterable {
    case sqrt, abs, ln, log, round, floor, ceil

    func apply(_ x: Double) throws -> Double {
        switch self {
        case .sqrt:
            guard x >= 0 else { throw EngineError.mathDomain("sqrt") }
            return x.squareRoot()
        case .abs:   return Swift.abs(x)
        case .ln:
            guard x > 0 else { throw EngineError.mathDomain("ln") }
            return Foundation.log(x)
        case .log:
            guard x > 0 else { throw EngineError.mathDomain("log") }
            return Foundation.log10(x)
        case .round: return x.rounded()
        case .floor: return x.rounded(.down)
        case .ceil:  return x.rounded(.up)
        }
    }
}

/// Named numbers. Resolved by the tokenizer, so the parser never sees them.
enum MathConstant: String, CaseIterable {
    case pi, e

    var value: Double {
        switch self {
        case .pi: return Double.pi
        case .e:  return M_E
        }
    }
}

public enum Operator: Equatable {
    case add, subtract, multiply, divide
    case power       // ^ or **, right-associative
    case negate      // unary minus, prefix
    case percent     // postfix, divides by 100

    /// Higher binds tighter.
    ///
    /// `negate` sits BELOW `power` on purpose. Standard maths reads `-2^2` as `-(2^2)`,
    /// so the exponent must bind tighter than a leading minus.
    var precedence: Int {
        switch self {
        case .add, .subtract:    return 1
        case .multiply, .divide: return 2
        case .negate:            return 3
        case .power:             return 4
        case .percent:           return 5
        }
    }

    var isRightAssociative: Bool { self == .power || self == .negate }

    /// Unary operators take one operand; the rest take two.
    var isUnary: Bool { self == .negate || self == .percent }

    /// Prefix operators bind to what follows them, so they never pop pending operators.
    /// Without this, `2^-3` would pop `^` when the minus arrives and evaluate wrongly.
    var isPrefix: Bool { self == .negate }
}

public enum Token: Equatable {
    case number(Double)
    case op(Operator)
    case function(MathFunction)
    case leftParen
    case rightParen
}

public enum Tokenizer {

    public static func tokenize(_ input: String) throws -> [Token] {
        var tokens: [Token] = []
        var chars = Array(input)
        var i = 0

        while i < chars.count {
            let c = chars[i]

            if c.isWhitespace { i += 1; continue }

            if c.isLetter {
                var name = ""
                while i < chars.count, chars[i].isLetter {
                    name.append(chars[i])
                    i += 1
                }
                let lower = name.lowercased()

                if let constant = MathConstant(rawValue: lower) {
                    tokens.append(.number(constant.value))
                    continue
                }
                guard let fn = MathFunction(rawValue: lower) else {
                    throw EngineError.unknownIdentifier(lower)
                }
                // Parentheses are required: `sqrt9^2` would otherwise have two plausible
                // readings, and this expression is re-evaluated on every keystroke.
                var j = i
                while j < chars.count, chars[j].isWhitespace { j += 1 }
                guard j < chars.count, chars[j] == "(" else {
                    throw EngineError.expectedParenthesis(lower)
                }
                tokens.append(.function(fn))
                continue
            }

            if c.isNumber || c == "." {
                var literal = ""
                while i < chars.count, chars[i].isNumber || chars[i] == "." {
                    literal.append(chars[i])
                    i += 1
                }
                guard literal.filter({ $0 == "." }).count <= 1,
                      let value = Double(literal) else {
                    throw EngineError.malformedNumber(literal)
                }
                tokens.append(.number(value))
                continue
            }

            switch c {
            case "+": tokens.append(.op(.add))
            case "^": tokens.append(.op(.power))
            case "*", "×":
                // "**" is a power, and people type it.
                if c == "*", i + 1 < chars.count, chars[i + 1] == "*" {
                    tokens.append(.op(.power))
                    i += 1
                } else {
                    tokens.append(.op(.multiply))
                }
            case "/", "÷": tokens.append(.op(.divide))
            case "%": tokens.append(.op(.percent))
            case "(": tokens.append(.leftParen)
            case ")": tokens.append(.rightParen)
            case "-", "−":
                // Minus is unary at the start, after another operator, or after "(".
                // Anywhere else it is subtraction.
                tokens.append(.op(isUnaryContext(tokens.last) ? .negate : .subtract))
            default:
                throw EngineError.unexpectedCharacter(c)
            }
            i += 1
        }

        return tokens
    }

    private static func isUnaryContext(_ previous: Token?) -> Bool {
        switch previous {
        case .none, .leftParen, .function:
            return true
        case .op(let o):
            // A percent completes its operand, so a minus after it is subtraction.
            return o != .percent
        case .number, .rightParen:
            return false
        }
    }
}
