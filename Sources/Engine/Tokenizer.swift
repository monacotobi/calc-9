import Foundation

/// Anything that can go wrong turning text into a number.
public enum EngineError: Error, Equatable {
    case unexpectedCharacter(Character)
    case malformedNumber(String)
    case unbalancedParentheses
    case incompleteExpression
    case divisionByZero
}

public enum Operator: Equatable {
    case add, subtract, multiply, divide
    case negate      // unary minus
    case percent     // postfix, divides by 100

    /// Higher binds tighter.
    var precedence: Int {
        switch self {
        case .add, .subtract:      return 1
        case .multiply, .divide:   return 2
        case .negate:              return 3
        case .percent:             return 4
        }
    }

    var isRightAssociative: Bool { self == .negate }

    /// Unary operators take one operand; the rest take two.
    var isUnary: Bool { self == .negate || self == .percent }
}

public enum Token: Equatable {
    case number(Double)
    case op(Operator)
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
            case "*", "×": tokens.append(.op(.multiply))
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
        case .none, .leftParen:
            return true
        case .op(let o):
            // A percent completes its operand, so a minus after it is subtraction.
            return o != .percent
        case .number, .rightParen:
            return false
        }
    }
}
