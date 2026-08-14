import XCTest
@testable import Calc9Engine

final class PowerTests: XCTestCase {

    private func eval(_ s: String) throws -> Double { try Engine.evaluate(s) }

    func testBasicPower() throws {
        XCTAssertEqual(try eval("2^3"), 8)
        XCTAssertEqual(try eval("9^0.5"), 3, accuracy: 1e-12)
        XCTAssertEqual(try eval("5^0"), 1)
    }

    /// `**` is accepted as an alias, because people type it.
    func testDoubleStarAlias() throws {
        XCTAssertEqual(try eval("2**3"), 8)
        XCTAssertEqual(try eval("2**3**2"), 512)
    }

    /// Right-associative: 2^(3^2) = 2^9, not (2^3)^2 = 64.
    func testRightAssociative() throws {
        XCTAssertEqual(try eval("2^3^2"), 512)
    }

    func testBindsTighterThanMultiplication() throws {
        XCTAssertEqual(try eval("2*3^2"), 18)   // not 36
        XCTAssertEqual(try eval("3^2*2"), 18)
        XCTAssertEqual(try eval("1+2^3"), 9)
    }

    /// Standard maths convention: the exponent binds tighter than a leading minus,
    /// so -2^2 is -(2^2) = -4, NOT (-2)^2 = 4.
    func testUnaryMinusOnTheLeftIsWeaker() throws {
        XCTAssertEqual(try eval("-2^2"), -4)
        XCTAssertEqual(try eval("-(2^2)"), -4)
        XCTAssertEqual(try eval("(-2)^2"), 4)
    }

    /// ...but a minus inside the exponent must still work.
    func testNegativeExponent() throws {
        XCTAssertEqual(try eval("2^-3"), 0.125, accuracy: 1e-12)
        XCTAssertEqual(try eval("10^-2"), 0.01, accuracy: 1e-12)
    }

    func testParenthesesWithPower() throws {
        XCTAssertEqual(try eval("(1+1)^3"), 8)
        XCTAssertEqual(try eval("2^(1+2)"), 8)
    }

    func testLivePreviewHandlesTrailingCaret() {
        XCTAssertEqual(Engine.livePreview(of: "2^"), 2)
        XCTAssertEqual(Engine.livePreview(of: "2^3"), 8)
    }
}

final class ExpressionBufferTests: XCTestCase {

    func testAppendsAtCaret() {
        var b = ExpressionBuffer()
        b.insert("1"); b.insert("2"); b.insert("3")
        XCTAssertEqual(b.text, "123")
        XCTAssertEqual(b.caret, 3)
    }

    func testInsertInMiddle() {
        var b = ExpressionBuffer(text: "13", caret: 1)
        b.insert("2")
        XCTAssertEqual(b.text, "123")
        XCTAssertEqual(b.caret, 2)
    }

    func testInsertMultiCharacterString() {
        var b = ExpressionBuffer(text: "ab", caret: 1)
        b.insert("XY")
        XCTAssertEqual(b.text, "aXYb")
        XCTAssertEqual(b.caret, 3)
    }

    func testMoveLeftAndRightClamp() {
        var b = ExpressionBuffer(text: "abc", caret: 3)
        b.moveLeft(); XCTAssertEqual(b.caret, 2)
        b.moveLeft(); b.moveLeft(); XCTAssertEqual(b.caret, 0)
        b.moveLeft(); XCTAssertEqual(b.caret, 0, "must not go negative")
        b.moveRight(); XCTAssertEqual(b.caret, 1)
        b.moveToEnd(); XCTAssertEqual(b.caret, 3)
        b.moveRight(); XCTAssertEqual(b.caret, 3, "must not exceed length")
        b.moveToStart(); XCTAssertEqual(b.caret, 0)
    }

    func testDeleteBackward() {
        var b = ExpressionBuffer(text: "123", caret: 2)
        b.deleteBackward()
        XCTAssertEqual(b.text, "13")
        XCTAssertEqual(b.caret, 1)
    }

    func testDeleteBackwardAtStartDoesNothing() {
        var b = ExpressionBuffer(text: "123", caret: 0)
        b.deleteBackward()
        XCTAssertEqual(b.text, "123")
        XCTAssertEqual(b.caret, 0)
    }

    func testDeleteForward() {
        var b = ExpressionBuffer(text: "123", caret: 1)
        b.deleteForward()
        XCTAssertEqual(b.text, "13")
        XCTAssertEqual(b.caret, 1, "caret stays put when deleting forward")
    }

    func testDeleteForwardAtEndDoesNothing() {
        var b = ExpressionBuffer(text: "123", caret: 3)
        b.deleteForward()
        XCTAssertEqual(b.text, "123")
    }

    func testClear() {
        var b = ExpressionBuffer(text: "123", caret: 2)
        b.clear()
        XCTAssertEqual(b.text, "")
        XCTAssertEqual(b.caret, 0)
    }

    /// The caret splits the string for rendering; both halves must round-trip.
    func testSplitForRendering() {
        let b = ExpressionBuffer(text: "44*12+", caret: 3)
        XCTAssertEqual(b.before, "44*")
        XCTAssertEqual(b.after, "12+")
        XCTAssertEqual(b.before + b.after, b.text)
    }

    func testInitClampsOutOfRangeCaret() {
        XCTAssertEqual(ExpressionBuffer(text: "ab", caret: 99).caret, 2)
        XCTAssertEqual(ExpressionBuffer(text: "ab", caret: -5).caret, 0)
    }
}
