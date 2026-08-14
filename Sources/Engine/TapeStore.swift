import Foundation

/// One committed calculation.
public struct TapeEntry: Equatable, Identifiable {
    public let id = UUID()
    public let expression: String
    public let value: Double

    public init(expression: String, value: Double) {
        self.expression = expression
        self.value = value
    }

    public static func == (a: TapeEntry, b: TapeEntry) -> Bool {
        a.expression == b.expression && a.value == b.value
    }
}

/// The last few results, newest first.
///
/// Lives in the Engine target rather than the UI so it can be tested without AppKit. The
/// UI wraps it in an ObservableObject.
public struct Tape: Equatable {
    public private(set) var entries: [TapeEntry] = []
    public let capacity: Int

    public init(capacity: Int = 3) {
        self.capacity = capacity
    }

    /// Newest entry first. Anything past `capacity` falls off the end.
    public mutating func add(expression: String, value: Double) {
        entries.insert(TapeEntry(expression: expression, value: value), at: 0)
        if entries.count > capacity {
            entries = Array(entries.prefix(capacity))
        }
    }

    public mutating func clear() {
        entries.removeAll()
    }

    public var isEmpty: Bool { entries.isEmpty }
    public var count: Int { entries.count }

    public subscript(index: Int) -> TapeEntry? {
        entries.indices.contains(index) ? entries[index] : nil
    }
}
