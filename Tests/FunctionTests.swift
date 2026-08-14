import XCTest
@testable import Calc9Engine

final class FunctionTests: XCTestCase {

    private func eval(_ s: String) throws -> Double { try Engine.evaluate(s) }

    func testSquareRoot() throws {
        XCTAssertEqual(try eval("sqrt(9)"), 3)
        XCTAssertEqual(try eval("sqrt(2)"), 2.0.squareRoot(), accuracy: 1e-12)
        XCTAssertEqual(try eval("sqrt(16)+1"), 5)
    }

    func testNestedAndComposed() throws {
        XCTAssertEqual(try eval("sqrt(sqrt(16))"), 2)
        XCTAssertEqual(try eval("sqrt(9)*sqrt(4)"), 6)
        XCTAssertEqual(try eval("sqrt(3^2+4^2)"), 5, accuracy: 1e-12)
    }

    func testOtherFunctions() throws {
        XCTAssertEqual(try eval("abs(-5)"), 5)
        XCTAssertEqual(try eval("round(2.6)"), 3)
        XCTAssertEqual(try eval("floor(2.9)"), 2)
        XCTAssertEqual(try eval("ceil(2.1)"), 3)
        XCTAssertEqual(try eval("log(1000)"), 3, accuracy: 1e-12)
        XCTAssertEqual(try eval("ln(1)"), 0)
    }

    func testConstants() throws {
        XCTAssertEqual(try eval("pi"), Double.pi, accuracy: 1e-12)
        XCTAssertEqual(try eval("2*pi"), 2 * Double.pi, accuracy: 1e-12)
        XCTAssertEqual(try eval("e"), M_E, accuracy: 1e-12)
        XCTAssertEqual(try eval("ln(e)"), 1, accuracy: 1e-12)
    }

    func testCaseInsensitive() throws {
        XCTAssertEqual(try eval("SQRT(9)"), 3)
        XCTAssertEqual(try eval("Sqrt(9)"), 3)
        XCTAssertEqual(try eval("PI"), Double.pi, accuracy: 1e-12)
    }

    /// Decided: parentheses are required. Allowing `sqrt9` makes `sqrt9^2` ambiguous, and
    /// this field re-evaluates on every keystroke, so ambiguity shows up as flicker.
    func testParenthesesAreRequired() {
        XCTAssertThrowsError(try eval("sqrt9")) { error in
            XCTAssertEqual(error as? EngineError, .expectedParenthesis("sqrt"))
        }
        XCTAssertThrowsError(try eval("sqrt 9"))
    }

    /// Real-valued domain errors must be reported, not silently returned as NaN — a tape
    /// entry reading "nan" is worse than a message.
    func testDomainErrors() {
        XCTAssertThrowsError(try eval("sqrt(-1)")) { error in
            XCTAssertEqual(error as? EngineError, .mathDomain("sqrt"))
        }
        XCTAssertThrowsError(try eval("ln(0)"))
        XCTAssertThrowsError(try eval("ln(-1)"))
        XCTAssertThrowsError(try eval("log(0)"))
    }

    func testUnknownName() {
        XCTAssertThrowsError(try eval("frobnicate(2)")) { error in
            XCTAssertEqual(error as? EngineError, .unknownIdentifier("frobnicate"))
        }
    }

    func testUnaryMinusAppliesToFunctionResult() throws {
        XCTAssertEqual(try eval("-sqrt(9)"), -3)
        XCTAssertEqual(try eval("2*-sqrt(4)"), -4)
    }

    func testPowerOfFunctionResult() throws {
        XCTAssertEqual(try eval("sqrt(9)^2"), 9, accuracy: 1e-12)
    }

    /// While typing "sqrt(9" nothing should be shown rather than a misleading value.
    func testLivePreviewWhileTypingAFunction() {
        XCTAssertNil(Engine.livePreview(of: "sqrt("))
        XCTAssertNil(Engine.livePreview(of: "sqrt(9"))
        XCTAssertEqual(Engine.livePreview(of: "sqrt(9)"), 3)
        // A completed call followed by a pending operator falls back to the call.
        XCTAssertEqual(Engine.livePreview(of: "sqrt(9)+"), 3)
    }
}
