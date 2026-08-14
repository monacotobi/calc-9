import Foundation

public enum Evaluator {

    public static func evaluate(rpn: [Token]) throws -> Double {
        var stack: [Double] = []

        for token in rpn {
            switch token {
            case .number(let v):
                stack.append(v)

            case .function(let fn):
                guard let a = stack.popLast() else { throw EngineError.incompleteExpression }
                stack.append(try fn.apply(a))

            case .op(let o) where o.isUnary:
                guard let a = stack.popLast() else { throw EngineError.incompleteExpression }
                stack.append(o == .negate ? -a : a / 100)

            case .op(let o):
                guard let b = stack.popLast(), let a = stack.popLast() else {
                    throw EngineError.incompleteExpression
                }
                switch o {
                case .add:      stack.append(a + b)
                case .subtract: stack.append(a - b)
                case .multiply: stack.append(a * b)
                case .divide:
                    guard b != 0 else { throw EngineError.divisionByZero }
                    stack.append(a / b)
                case .power:
                    let result = pow(a, b)
                    // e.g. (-8)^0.5 — real-valued exponentiation is undefined here.
                    guard result.isFinite || a != 0 else { throw EngineError.divisionByZero }
                    stack.append(result)
                default:
                    throw EngineError.incompleteExpression
                }

            case .leftParen, .rightParen:
                throw EngineError.unbalancedParentheses
            }
        }

        guard stack.count == 1, let result = stack.first else {
            throw EngineError.incompleteExpression
        }
        guard result.isFinite else { throw EngineError.divisionByZero }
        return result
    }
}
