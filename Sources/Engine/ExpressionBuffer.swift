import Foundation

/// The expression being typed, plus a caret position.
///
/// Lives in the engine rather than the view so the index arithmetic can be tested — this
/// is exactly the code that produces off-by-one bugs.
public struct ExpressionBuffer: Equatable {

    public private(set) var text: String
    public private(set) var caret: Int

    public init(text: String = "", caret: Int? = nil) {
        self.text = text
        self.caret = min(max(caret ?? text.count, 0), text.count)
    }

    // MARK: Rendering

    /// Everything left of the caret.
    public var before: String { String(text.prefix(caret)) }
    /// Everything right of the caret.
    public var after: String { String(text.dropFirst(caret)) }

    public var isEmpty: Bool { text.isEmpty }

    // MARK: Editing

    public mutating func insert(_ s: String) {
        guard !s.isEmpty else { return }
        let index = text.index(text.startIndex, offsetBy: caret)
        text.insert(contentsOf: s, at: index)
        caret += s.count
    }

    public mutating func deleteBackward() {
        guard caret > 0 else { return }
        let index = text.index(text.startIndex, offsetBy: caret - 1)
        text.remove(at: index)
        caret -= 1
    }

    /// Deletes the character to the right; the caret does not move.
    public mutating func deleteForward() {
        guard caret < text.count else { return }
        let index = text.index(text.startIndex, offsetBy: caret)
        text.remove(at: index)
    }

    public mutating func clear() {
        text = ""
        caret = 0
    }

    // MARK: Caret

    public mutating func moveLeft()    { caret = max(0, caret - 1) }
    public mutating func moveRight()   { caret = min(text.count, caret + 1) }
    public mutating func moveToStart() { caret = 0 }
    public mutating func moveToEnd()   { caret = text.count }
}
