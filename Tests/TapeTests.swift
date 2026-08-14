import XCTest
@testable import Calc9Engine

final class TapeTests: XCTestCase {

    func testStartsEmpty() {
        let tape = Tape()
        XCTAssertTrue(tape.isEmpty)
        XCTAssertEqual(tape.count, 0)
    }

    func testNewestFirst() {
        var tape = Tape()
        tape.add(expression: "1+1", value: 2)
        tape.add(expression: "2+2", value: 4)
        XCTAssertEqual(tape.entries.map(\.expression), ["2+2", "1+1"])
    }

    func testCapsAtThree() {
        var tape = Tape()
        for i in 1...5 {
            tape.add(expression: "\(i)+0", value: Double(i))
        }
        XCTAssertEqual(tape.count, 3)
        XCTAssertEqual(tape.entries.map(\.value), [5, 4, 3])
    }

    func testCapacityIsConfigurable() {
        var tape = Tape(capacity: 1)
        tape.add(expression: "1", value: 1)
        tape.add(expression: "2", value: 2)
        XCTAssertEqual(tape.entries.map(\.value), [2])
    }

    /// Duplicates are kept, unlike Clip-9's clipboard history. Calculating the same thing
    /// twice is a real event worth seeing on the tape, not a duplicate to collapse.
    func testDuplicatesAreKept() {
        var tape = Tape()
        tape.add(expression: "2+2", value: 4)
        tape.add(expression: "2+2", value: 4)
        XCTAssertEqual(tape.count, 2)
    }

    func testSubscriptIsBoundsSafe() {
        var tape = Tape()
        tape.add(expression: "1+1", value: 2)
        XCTAssertEqual(tape[0]?.value, 2)
        XCTAssertNil(tape[1])
        XCTAssertNil(tape[-1])
    }

    func testClear() {
        var tape = Tape()
        tape.add(expression: "1+1", value: 2)
        tape.clear()
        XCTAssertTrue(tape.isEmpty)
    }
}
