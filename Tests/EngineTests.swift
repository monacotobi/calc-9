import XCTest
@testable import Calc9Engine

// The engine is pure Swift with no AppKit, which is the whole reason it can be tested
// like this. Everything below runs without a window server.

final class TokenizerTests: XCTestCase {

    func testDigitsAndOperators() throws {
        XCTAssertEqual(try Tokenizer.tokenize("1+2"),
                       [.number(1), .op(.add), .number(2)])
    }

    func testDecimals() throws {
        XCTAssertEqual(try Tokenizer.tokenize("0.15*4"),
                       [.number(0.15), .op(.multiply), .number(4)])
    }

    func testWhitespaceIsIgnored() throws {
        XCTAssertEqual(try Tokenizer.tokenize("  12  +  3 "),
                       [.number(12), .op(.add), .number(3)])
    }

    func testParentheses() throws {
        XCTAssertEqual(try Tokenizer.tokenize("(1)"),
                       [.leftParen, .number(1), .rightParen])
    }

    /// A minus is unary at the start of an expression, after another operator, or after
    /// an opening paren. Everywhere else it is subtraction.
    func testUnaryVersusBinaryMinus() throws {
        XCTAssertEqual(try Tokenizer.tokenize("-5"), [.op(.negate), .number(5)])
        XCTAssertEqual(try Tokenizer.tokenize("3-5"),
                       [.number(3), .op(.subtract), .number(5)])
        XCTAssertEqual(try Tokenizer.tokenize("3*-5"),
                       [.number(3), .op(.multiply), .op(.negate), .number(5)])
        XCTAssertEqual(try Tokenizer.tokenize("(-5)"),
                       [.leftParen, .op(.negate), .number(5), .rightParen])
    }

    func testPercentIsPostfix() throws {
        XCTAssertEqual(try Tokenizer.tokenize("50%"), [.number(50), .op(.percent)])
    }

    func testRejectsUnknownCharacter() {
        XCTAssertThrowsError(try Tokenizer.tokenize("2 $ 3")) { error in
            XCTAssertEqual(error as? EngineError, .unexpectedCharacter("$"))
        }
    }

    func testRejectsMalformedNumber() {
        XCTAssertThrowsError(try Tokenizer.tokenize("1.2.3"))
    }
}

final class EvaluatorTests: XCTestCase {

    private func eval(_ s: String) throws -> Double {
        try Engine.evaluate(s)
    }

    func testArithmetic() throws {
        XCTAssertEqual(try eval("1+2"), 3)
        XCTAssertEqual(try eval("10-4"), 6)
        XCTAssertEqual(try eval("6*7"), 42)
        XCTAssertEqual(try eval("9/2"), 4.5)
    }

    func testPrecedence() throws {
        XCTAssertEqual(try eval("2+3*4"), 14)
        XCTAssertEqual(try eval("2*3+4"), 10)
        XCTAssertEqual(try eval("100-10/2"), 95)
    }

    func testParenthesesOverridePrecedence() throws {
        XCTAssertEqual(try eval("(2+3)*4"), 20)
        XCTAssertEqual(try eval("(120+80)*3"), 600)
        XCTAssertEqual(try eval("((1+2)*(3+4))"), 21)
    }

    func testLeftAssociativity() throws {
        XCTAssertEqual(try eval("10-3-2"), 5)   // not 9
        XCTAssertEqual(try eval("100/10/2"), 5) // not 20
    }

    func testUnaryMinus() throws {
        XCTAssertEqual(try eval("-5"), -5)
        XCTAssertEqual(try eval("-5+3"), -2)
        XCTAssertEqual(try eval("3*-5"), -15)
        XCTAssertEqual(try eval("-(2+3)"), -5)
        XCTAssertEqual(try eval("--5"), 5)
    }

    /// Decided in the design: `%` divides by 100 and nothing else. `100+10%` is 100.1,
    /// NOT 110. Consumer calculators make `%` context-sensitive; that cannot be expressed
    /// in a precedence table and is unpredictable in a live-updating field.
    func testPercentIsAlwaysDivideByOneHundred() throws {
        XCTAssertEqual(try eval("50%"), 0.5)
        XCTAssertEqual(try eval("100+10%"), 100.1, accuracy: 1e-12)
        XCTAssertEqual(try eval("200*10%"), 20, accuracy: 1e-12)
    }

    func testDivisionByZeroThrows() {
        XCTAssertThrowsError(try eval("1/0")) { error in
            XCTAssertEqual(error as? EngineError, .divisionByZero)
        }
        XCTAssertThrowsError(try eval("5/(3-3)")) { error in
            XCTAssertEqual(error as? EngineError, .divisionByZero)
        }
    }

    func testUnbalancedParenthesesThrow() {
        XCTAssertThrowsError(try eval("(1+2"))
        XCTAssertThrowsError(try eval("1+2)"))
    }

    func testIncompleteExpressionThrows() {
        XCTAssertThrowsError(try eval("1+"))
        XCTAssertThrowsError(try eval("*3"))
        XCTAssertThrowsError(try eval(""))
    }
}

final class LivePreviewTests: XCTestCase {

    /// While typing, most expressions are incomplete. Blanking the result on every operator
    /// would make the field strobe, so the UI shows the value of the longest valid prefix.
    func testLongestValidPrefix() {
        XCTAssertEqual(Engine.livePreview(of: "44*12+"), 528)
        XCTAssertEqual(Engine.livePreview(of: "44*12"), 528)
        XCTAssertEqual(Engine.livePreview(of: "2+3*"), 5)
        XCTAssertEqual(Engine.livePreview(of: "(120+80)*3"), 600)
    }

    func testPrefixIgnoresUnclosedParen() {
        // "(2+3" has no valid prefix that is itself balanced, so nothing shows.
        XCTAssertNil(Engine.livePreview(of: "(2+3"))
    }

    func testNoValidPrefixGivesNil() {
        XCTAssertNil(Engine.livePreview(of: ""))
        XCTAssertNil(Engine.livePreview(of: "+"))
        XCTAssertNil(Engine.livePreview(of: "abc"))
    }

    /// A live preview must never surface a division-by-zero error mid-typing; errors are
    /// for Enter, when the user has asserted the expression is finished.
    func testDivisionByZeroPreviewIsNil() {
        XCTAssertNil(Engine.livePreview(of: "1/0"))
    }
}

final class FormattingTests: XCTestCase {

    func testThousandsSeparators() {
        XCTAssertEqual(Engine.format(5280), "5,280")
        XCTAssertEqual(Engine.format(1234567), "1,234,567")
        XCTAssertEqual(Engine.format(999), "999")
    }

    func testTrailingZerosTrimmed() {
        XCTAssertEqual(Engine.format(2.5), "2.5")
        XCTAssertEqual(Engine.format(2.0), "2")
        XCTAssertEqual(Engine.format(0.5), "0.5")
    }

    func testNegative() {
        XCTAssertEqual(Engine.format(-1500), "-1,500")
    }

    func testVeryLargeUsesScientific() {
        XCTAssertTrue(Engine.format(1e18).contains("e"))
    }
}
