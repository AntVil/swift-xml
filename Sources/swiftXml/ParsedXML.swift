public final class ParsedXML: Sendable {
    /// A tree stored as a single array for efficiency reasons.
    ///
    /// Values are encoded like this:
    /// | substring value | int value                   |
    /// | --------------- | --------------------------- |
    /// | tag-name        | end-index of tag            |
    /// | always empty    | positive index to child tag |
    /// |                 | negative index to content   |
    /// |                 | zero for no content         |
    /// | attribute key   | always zero                 |
    /// | attribute value | always zero                 |
    /// | tag-content     | always zero                 |
    private let tree: Array<(Substring, Int)>

    @inline(__always)
    public func isTag(at index: Int) throws -> Bool {
        try ensureInsideTree(at: index)

        return tree[index + 1].0 == ""
    }

    @inline(__always)
    public func hasChildren(at index: Int) throws -> Bool {
        guard try isTag(at: index) else {
            throw XMLTraversalError.notATag(at: index)
        }

        return tree[index + 1].1 > 0
    }

    @inline(__always)
    public func hasContent(at index: Int) throws -> Bool {
        guard try isTag(at: index) else {
            throw XMLTraversalError.notATag(at: index)
        }

        return tree[index + 1].1 < 0
    }

    @inline(__always)
    public func isEmpty(at index: Int) throws -> Bool {
        guard try isTag(at: index) else {
            throw XMLTraversalError.notATag(at: index)
        }

        return tree[index + 1].1 == 0
    }

    @inline(__always)
    private func ensureInsideTree(at index: Int) throws {
        guard index + 1 < tree.count else {
            throw XMLTraversalError.outsideTree(at: index)
        }
    }

    @inline(__always)
    private func ensureIsTag(at index: Int) throws {
        guard try isTag(at: index) else {
            throw XMLTraversalError.notATag(at: index)
        }
    }

    @inline(__always)
    private func ensureHasChildren(at index: Int) throws {
        guard try hasChildren(at: index) else {
            throw XMLTraversalError.noChildren(at: index)
        }
    }

    @inline(__always)
    private func ensureHasContent(at index: Int) throws {
        guard try hasContent(at: index) else {
            throw XMLTraversalError.noContent(at: index)
        }
    }

    func getChildren(of index: Int) throws -> [Int] {
        try ensureHasChildren(at: index)

        var children = [Int]()

        var childIndex = tree[index + 1].1
        let endIndex = tree[index].1
        while childIndex < endIndex {
            children.append(childIndex)
            childIndex = tree[childIndex].1
        }

        return children
    }

    func getTagName(of index: Int) throws -> Substring {
        try ensureIsTag(at: index)

        return tree[index].0
    }

    func getTagContent(of index: Int) throws -> Substring {
        try ensureHasContent(at: index)

        let contentIndex = -tree[index + 1].1

        guard contentIndex > 0 else {
            throw XMLTraversalError.noContent(at: index)
        }

        return tree[contentIndex].0
    }

    func getTagAttributes(of index: Int) throws -> [(Substring, Substring)] {
        try ensureIsTag(at: index)

        var attributeIndex = index + 2
        let endIndex = abs(tree[index + 1].1)

        guard endIndex != 0 else {
            // there is no content, so we don't know where attributes end
            var attributes = [(Substring, Substring)]()
            while attributeIndex < self.tree.count && self.tree[attributeIndex].1 == 0 {
                attributes.append((tree[attributeIndex].0, tree[attributeIndex + 1].0))
                attributeIndex += 2
            }
            return attributes
        }

        guard attributeIndex <= endIndex else {
            return []
        }

        var attributes = [(Substring, Substring)]()
        attributes.reserveCapacity((endIndex - attributeIndex) / 2)

        while attributeIndex < endIndex {
            attributes.append((tree[attributeIndex].0, tree[attributeIndex + 1].0))
            attributeIndex += 2
        }

        return attributes
    }

    public init(from xml: String) throws {
        enum State {
            // TODO: handle tag content
            case preFirstTagPadding
            case readFirstOpenTag
            case readingXmlDeclaration
            case readingClosingXmlDeclaration
            case preTagPadding
            case readTagStart
            case readingOpeningTag
            case preAttributePadding
            case readingAttributeKey
            case postAttributeKeyPadding
            case preAttributeValuePadding
            case readSingleQuotedStart
            case readDoubleQuotedStart
            case readingSingleQuoted
            case readingDoubleQuoted
            case readingSingleQuotedEscaped
            case readingDoubleQuotedEscaped
            case readUnnamedClosingTagStart
            case readNamedClosingTagStart
            case readingNamedClosingTag
            case postNamedClosingTag
            case readingCommentStartDash1
            case readingCommentStartDash2
            case readingCommentEndDash1
            case readingCommentEndDash2
            case readingCommentEnd
            case readingTagContent
            case postContent
        }

        var startStringIndex = xml.startIndex
        var endStringIndex = xml.startIndex
        var state = State.preFirstTagPadding

        var treeBuilder = TreeBuilder()

        for (index, character) in zip(xml.indices, xml) {
            switch state {
            case .preFirstTagPadding:
                guard character != " " && character != "\n" else {
                    continue
                }
                guard character == "<" else {
                    fatalError("A")
                }
                state = .readFirstOpenTag
            case .readFirstOpenTag:
                if character == "?" {
                    state = .readingXmlDeclaration
                } else if character == " " || character == "\n" {
                    fatalError("")
                } else if character == "/" {
                    fatalError("")
                } else if character == "!" {
                    state = .readingCommentStartDash1
                } else {
                    startStringIndex = index
                    state = .readingOpeningTag
                }
            case .readingXmlDeclaration:
                if character == "?" {
                    state = .readingClosingXmlDeclaration
                }
            case .readingClosingXmlDeclaration:
                guard character == ">" else {
                    fatalError()
                }
                let _ = xml[startStringIndex ... index]
                // TODO: validate declaration maybe?
                state = .preTagPadding
            case .preTagPadding:
                guard character != " " && character != "\n" else {
                    continue
                }
                if character == "<" {
                    startStringIndex = index
                    state = .readTagStart
                } else {
                    startStringIndex = index
                    state = .readingTagContent
                }
            case .readTagStart:
                guard character != " " && character != "\n" else {
                    fatalError()
                }
                guard character != "/" else {
                    startStringIndex = index
                    state = .readNamedClosingTagStart
                    continue
                }
                guard character != "!" else {
                    state = .readingCommentStartDash1
                    continue
                }
                state = .readingOpeningTag
                startStringIndex = index
            case .readingOpeningTag:
                guard character != " " && character != "\n" else {
                    let tagName = xml[startStringIndex ..< index]
                    treeBuilder.addTag(named: tagName)
                    state = .preAttributePadding
                    continue
                }
                guard character != "/" else {
                    let tagName = xml[startStringIndex ..< index]
                    treeBuilder.addTag(named: tagName)
                    try treeBuilder.closeTag()
                    state = .readUnnamedClosingTagStart
                    continue
                }
                guard character != ">" else {
                    let tagName = xml[startStringIndex ..< index]
                    treeBuilder.addTag(named: tagName)
                    state = .preTagPadding
                    continue
                }
            case .preAttributePadding:
                guard character != " " && character != "\n" else {
                    continue
                }
                guard character != "/" else {
                    state = .readUnnamedClosingTagStart
                    try treeBuilder.closeTag()
                    continue
                }
                guard character != ">" else {
                    state = .preTagPadding
                    continue
                }
                state = .readingAttributeKey
                startStringIndex = index
            case .readingAttributeKey:
                guard character != " " && character != "\n" else {
                    let attributeKey = xml[startStringIndex ..< index]
                    treeBuilder.addAttribute(key: attributeKey)
                    state = .postAttributeKeyPadding
                    continue
                }
                guard character != "=" else {
                    let attributeKey = xml[startStringIndex ..< index]
                    treeBuilder.addAttribute(key: attributeKey)
                    state = .preAttributeValuePadding
                    continue
                }
            case .postAttributeKeyPadding:
                guard character != "=" else {
                    state = .preAttributeValuePadding
                    continue
                }
                guard character == " " || character == "\n" else {
                    fatalError()
                }
            case .preAttributeValuePadding:
                guard character != " " && character != "\n" else {
                    continue
                }
                if character == "'" {
                    state = .readSingleQuotedStart
                } else if character == "\"" {
                    state = .readDoubleQuotedStart
                } else {
                    fatalError()
                }
            case .readSingleQuotedStart:
                guard character != "'" else {
                    treeBuilder.addAttribute(value: Substring())
                    state = .preAttributePadding
                    continue
                }
                startStringIndex = index
                guard character != "\\" else {
                    state = .readingSingleQuotedEscaped
                    continue
                }
                state = .readingSingleQuoted
            case .readingSingleQuoted:
                guard character != "'" else {
                    let attributeValue = xml[startStringIndex ..< index]
                    treeBuilder.addAttribute(value: Self.resolveEscapingAttribute(value: attributeValue, escapeEnd: "'"))
                    state = .preAttributePadding
                    continue
                }
                guard character != "\\" else {
                    state = .readingSingleQuotedEscaped
                    continue
                }
            case .readingSingleQuotedEscaped:
                guard character == "\\" || character == "'" else {
                    fatalError("got unexpected character: '\(character)' in state: '\(state)' substring: '\(xml[startStringIndex...index])'")
                }
                state = .readingSingleQuoted
            case .readDoubleQuotedStart:
                guard character != "\"" else {
                    treeBuilder.addAttribute(value: Substring())
                    state = .preAttributePadding
                    continue
                }
                startStringIndex = index
                guard character != "\\" else {
                    state = .readingDoubleQuotedEscaped
                    continue
                }
                state = .readingDoubleQuoted
            case .readingDoubleQuoted:
                guard character != "\"" else {
                    let attributeValue = xml[startStringIndex ..< index]
                    treeBuilder.addAttribute(value: Self.resolveEscapingAttribute(value: attributeValue, escapeEnd: "\""))
                    state = .preAttributePadding
                    continue
                }
                guard character != "\\" else {
                    state = .readingDoubleQuotedEscaped
                    continue
                }
            case .readingDoubleQuotedEscaped:
                guard character == "\\" || character == "\"" else {
                    fatalError("got unexpected character: '\(character)' in state: '\(state)' substring: '\(xml[startStringIndex...index])'")
                }
                state = .readingDoubleQuoted
            case .readUnnamedClosingTagStart:
                guard character == ">" else {
                    fatalError("got unexpected character: '\(character)' in state: '\(state)' substring: '\(xml[startStringIndex...index])'")
                }
                state = .preTagPadding
            case .readNamedClosingTagStart:
                startStringIndex = index
                state = .readingNamedClosingTag
            case .readingNamedClosingTag:
                if character == " " || character == "\n" {
                    let tagName = xml[startStringIndex ..< index]
                    try treeBuilder.closeTag(named: tagName)
                    state = .postNamedClosingTag
                }
                if character == ">" {
                    let tagName = xml[startStringIndex ..< index]
                    try treeBuilder.closeTag(named: tagName)
                    state = .preTagPadding
                }
            case .postNamedClosingTag:
                if character == " " || character == "\n" {
                    continue
                }
                if character == ">" {
                    let tagName = xml[startStringIndex ..< index]
                    try treeBuilder.closeTag(named: tagName)
                    state = .preTagPadding
                }
            case .readingCommentStartDash1:
                guard character == "-" else {
                    fatalError("ill formed comment")
                }
                state = .readingCommentStartDash2
            case .readingCommentStartDash2:
                guard character == "-" else {
                    fatalError("ill formed comment")
                }
                state = .readingCommentEndDash1
            case .readingCommentEndDash1:
                guard character == "-" else {
                    continue
                }
                state = .readingCommentEndDash2
            case .readingCommentEndDash2:
                guard character == "-" else {
                    state = .readingCommentEndDash1
                    continue
                }
                state = .readingCommentEnd
            case .readingCommentEnd:
                guard character == ">" else {
                    fatalError("ill formed xml")
                }
                state = .preTagPadding
            case .readingTagContent:
                if character == "<" {
                    let content = xml[startStringIndex ..< index]
                    try treeBuilder.addContent(value: Self.resolveEscapingContent(value: content))
                    state = .readTagStart
                } else if character == " " || character == "\n" {
                    endStringIndex = index
                    state = .postContent
                }
            case .postContent:
                if character == "<" {
                    let content = xml[startStringIndex ..< endStringIndex]
                    try treeBuilder.addContent(value: Self.resolveEscapingContent(value: content))
                    state = .readTagStart
                } else if character != " " && character != "\n" {
                    state = .readingTagContent
                }
            }
        }

        self.tree = treeBuilder.values
    }

    fileprivate static func resolveEscapingAttribute(value: Substring, escapeEnd: Character) -> Substring {
        return value.replacing("\\\\", with: "\\").replacing("\\\(escapeEnd)", with: "\(escapeEnd)")
    }

    fileprivate static func resolveEscapingContent(value: Substring) -> Substring {
        return value
            .replacing("&quot;", with: "\"")
            .replacing("&apos;", with: "'")
            .replacing("&lt;", with: "<")
            .replacing("&gt;", with: ">")
            .replacing("&amp;", with: "&")
    }

    struct TreeBuilder {
        private var openTagStack = Array<(Substring, Int)>()
        private(set) var values = Array<(Substring, Int)>()

        mutating func addTag(named name: Substring) {
            if let topElement = self.openTagStack.last, self.values[topElement.1 + 1].1 == 0 {
                self.values[topElement.1 + 1].1 = self.values.count
            }
            self.openTagStack.append((name, values.count))
            self.values.append((name, 0))
            self.values.append((Substring(), 0))
        }

        mutating func addAttribute(key: Substring) {
            self.values.append((key, 0))
        }

        mutating func addAttribute(value: Substring) {
            self.values.append((value, 0))
        }

        mutating func addContent(value: Substring) throws {
            guard let topElement = self.openTagStack.last else {
                fatalError()
            }
            self.values[topElement.1 + 1].1 = -self.values.count
            self.values.append((value, 0))
        }

        mutating func closeTag(named name: Substring) throws {
            guard !self.openTagStack.isEmpty else {
                throw XMLParserError.closedTagWithoutOpening(named: name)
            }
            let topElement = self.openTagStack.removeLast()

            guard topElement.0 == name else {
                throw XMLParserError.closingTagMismatch(got: name, expected: topElement.0)
            }
            self.values[topElement.1].1 = self.values.count
        }

        mutating func closeTag() throws {
            guard !self.openTagStack.isEmpty else {
                throw XMLParserError.closedTagWithoutOpeningUnnamed
            }
            let topElement = self.openTagStack.removeLast()

            self.values[topElement.1].1 = self.values.count
        }
    }
}

public enum XMLParserError: Error {
    case closedTagWithoutOpening(named: Substring)
    case closedTagWithoutOpeningUnnamed
    case closingTagMismatch(got: Substring, expected: Substring)
    case unexpectedEndOfXml
}

public enum XMLTraversalError: Error {
    case outsideTree(at: Int)
    case notATag(at: Int)
    case noChildren(at: Int)
    case noContent(at: Int)
}
