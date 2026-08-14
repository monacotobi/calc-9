import Foundation

/// Converts infix tokens to Reverse Polish Notation with the shunting-yard algorithm,
/// so the evaluator never has to think about precedence or parentheses.
public enum Parser {

    public static func toRPN(_ tokens: [Token]) throws -> [Token] {
        var output: [Token] = []
        var stack: [Token] = []

        for token in tokens {
            switch token {
            case .number:
                output.append(token)

            case .op(let o):
                if o == .percent {
                    // Postfix: its operand is already emitted, so it goes straight out.
                    output.append(token)
                    continue
                }
                while case .op(let top)? = stack.last,
                      top != .percent,
                      top.precedence > o.precedence
                        || (top.precedence == o.precedence && !o.isRightAssociative) {
                    output.append(stack.removeLast())
                }
                stack.append(token)

            case .leftParen:
                stack.append(token)

            case .rightParen:
                var foundLeft = false
                while let top = stack.popLast() {
                    if top == .leftParen { foundLeft = true; break }
                    output.append(top)
                }
                guard foundLeft else { throw EngineError.unbalancedParentheses }
            }
        }

        while let top = stack.popLast() {
            guard top != .leftParen else { throw EngineError.unbalancedParentheses }
            output.append(top)
        }

        return output
    }
}
