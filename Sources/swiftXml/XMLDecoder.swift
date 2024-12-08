import Foundation

public struct XMLDecoder: Sendable {
    public var userInfo: [CodingUserInfoKey: Sendable] = [:]
    public var nilDecodingStrategy: NilDecodingStrategy = .empty
    public var boolDecodingStrategy: BoolDecodingStrategy = .trueOrFalse

    public init() {}

    public func decode<T: Decodable>(_: T.Type, from xml: String) throws -> T {
        let parsedXML = try ParsedXML(from: xml)
        let decoder = XMLContainerDecoder(
            xml: parsedXML,
            userInfo: self.userInfo,
            options: XMLDecoderOptions(
                nilDecodingStrategy: self.nilDecodingStrategy,
                boolDecodingStrategy: self.boolDecodingStrategy
            ),
            tagIndex: 0
        )

        return try T.init(from: decoder)
    }

    public enum NilDecodingStrategy: Sendable {
        case never
        case empty
        case null
        case custom(nil: String)

        var nilLiteral: Substring? {
            switch self {
            case .never: return nil
            case .empty: return ""
            case .null: return "null"
            case .custom(let literal): return Substring(literal)
            }
        }
    }

    public enum BoolDecodingStrategy: Sendable {
        case trueOrFalse
        case zeroOrOne
        case custom(true: String, false: String)

        var trueLiteral: Substring {
            switch self {
            case .trueOrFalse: return "true"
            case .zeroOrOne: return "1"
            case .custom(let literal, _): return Substring(literal)
            }
        }
        var falseLiteral: Substring {
            switch self {
            case .trueOrFalse: return "false"
            case .zeroOrOne: return "0"
            case .custom(_, let literal): return Substring(literal)
            }
        }
    }
}

fileprivate struct XMLDecoderOptions {
    let nilLiteral: Substring?
    let trueLiteral: Substring
    let falseLiteral: Substring

    init(nilDecodingStrategy: XMLDecoder.NilDecodingStrategy, boolDecodingStrategy: XMLDecoder.BoolDecodingStrategy) {
        self.nilLiteral = nilDecodingStrategy.nilLiteral
        self.trueLiteral = boolDecodingStrategy.trueLiteral
        self.falseLiteral = boolDecodingStrategy.falseLiteral
    }
}

fileprivate final class XMLContainerDecoder: Decoder, Sendable {
    let xml: ParsedXML
    let userInfoSendable: [CodingUserInfoKey: Sendable]
    let options: XMLDecoderOptions
    let tagIndex: Int

    let codingPath: [any CodingKey] = []
    var userInfo: [CodingUserInfoKey: Any] { self.userInfoSendable }

    init(xml: ParsedXML, userInfo: [CodingUserInfoKey: Sendable], options: XMLDecoderOptions, tagIndex: Int) {
        self.xml = xml
        self.userInfoSendable = userInfo
        self.options = options
        self.tagIndex = tagIndex
    }

    func container<Key: CodingKey>(keyedBy: Key.Type) throws -> KeyedDecodingContainer<Key> {
        return KeyedDecodingContainer(XMLContainer<Key>(decoder: self))
    }

    func unkeyedContainer() throws -> any UnkeyedDecodingContainer {
        throw DecodingError.valueNotFound(
            Array<any Decodable>.self,
            DecodingError.Context(codingPath: [], debugDescription: "Unsupported decoding method 'unkeyedContainer' for xml decoder.")
        )
    }

    func singleValueContainer() throws -> any SingleValueDecodingContainer {
        throw DecodingError.valueNotFound(
            Array<any Decodable>.self,
            DecodingError.Context(codingPath: [], debugDescription: "Unsupported decoding method 'singleValueContainer' for xml decoder.")
        )
    }
}

fileprivate struct XMLContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {
    let decoder: XMLContainerDecoder
    let attributes: [(Substring, Substring)]

    init(decoder: XMLContainerDecoder) {
        self.decoder = decoder
        self.attributes = try! decoder.xml.getTagAttributes(of: decoder.tagIndex)
    }

    let codingPath: [any CodingKey] = []
    var allKeys: [Key] {
        return attributes.compactMap { Key(stringValue: String($0.0)) }
    }

    func getContent(forKey key: Key) throws -> Substring {
        guard key.stringValue != "" else {
            guard try self.decoder.xml.hasContent(at: self.decoder.tagIndex) else {
                throw DecodingError.valueNotFound(
                    Bool.self,
                    DecodingError.Context(codingPath: self.codingPath + [key], debugDescription: "Tag has no content which can be decoded as 'Bool'.")
                )
            }
            return try self.decoder.xml.getTagContent(of: self.decoder.tagIndex)
        }

        guard let attribute = self.attributes.first(where: { $0.0 == key.stringValue }) else {
            throw DecodingError.keyNotFound(
                key,
                DecodingError.Context(codingPath: self.codingPath + [key], debugDescription: "Tag doesn't have the specified attribute to decode as 'Bool'.")
            )
        }

        return attribute.1
    }

    func decode(_: Bool.Type, forKey key: Key) throws -> Bool {
        guard key.stringValue != "$" else {
            throw DecodingError.typeMismatch(
                Bool.self,
                DecodingError.Context(codingPath: self.codingPath + [key], debugDescription: "Cannot decode tag-name as 'Bool'.")
            )
        }

        let content = try getContent(forKey: key)

        if content == self.decoder.options.trueLiteral {
            return true
        } else if content == self.decoder.options.falseLiteral {
            return false
        } else {
            throw DecodingError.typeMismatch(
                Bool.self,
                DecodingError.Context(codingPath: self.codingPath + [key], debugDescription: "Couldn't decode 'Bool'.")
            )
        }
    }

    func decode(_: Int.Type, forKey key: Key) throws -> Int {
        guard key.stringValue != "$" else {
            throw DecodingError.typeMismatch(
                Bool.self,
                DecodingError.Context(codingPath: self.codingPath + [key], debugDescription: "Cannot decode tag-name as 'Int'.")
            )
        }

        let content = try getContent(forKey: key)

        guard let result = Int(content) else {
            throw DecodingError.typeMismatch(
                Bool.self,
                DecodingError.Context(codingPath: self.codingPath + [key], debugDescription: "Couldn't decode 'Int64'.")
            )
        }
        return result
    }

    func decode(_: Int64.Type, forKey key: Key) throws -> Int64 {
        guard key.stringValue != "$" else {
            throw DecodingError.typeMismatch(
                Bool.self,
                DecodingError.Context(codingPath: self.codingPath + [key], debugDescription: "Cannot decode tag-name as 'Int64'.")
            )
        }

        let content = try getContent(forKey: key)

        guard let result = Int64(content) else {
            throw DecodingError.typeMismatch(
                Bool.self,
                DecodingError.Context(codingPath: self.codingPath + [key], debugDescription: "Couldn't decode 'Int64'.")
            )
        }
        return result
    }

    func decode(_: Int32.Type, forKey key: Key) throws -> Int32 {
        guard key.stringValue != "$" else {
            throw DecodingError.typeMismatch(
                Bool.self,
                DecodingError.Context(codingPath: self.codingPath + [key], debugDescription: "Cannot decode tag-name as 'Int32'.")
            )
        }

        let content = try getContent(forKey: key)

        guard let result = Int32(content) else {
            throw DecodingError.typeMismatch(
                Bool.self,
                DecodingError.Context(codingPath: self.codingPath + [key], debugDescription: "Couldn't decode 'Int32'.")
            )
        }
        return result
    }

    func decode(_: Int16.Type, forKey key: Key) throws -> Int16 {
        guard key.stringValue != "$" else {
            throw DecodingError.typeMismatch(
                Bool.self,
                DecodingError.Context(codingPath: self.codingPath + [key], debugDescription: "Cannot decode tag-name as 'Int16'.")
            )
        }

        let content = try getContent(forKey: key)

        guard let result = Int16(content) else {
            throw DecodingError.typeMismatch(
                Bool.self,
                DecodingError.Context(codingPath: self.codingPath + [key], debugDescription: "Couldn't decode 'Int16'.")
            )
        }
        return result
    }

    func decode(_: Int8.Type, forKey key: Key) throws -> Int8 {
        guard key.stringValue != "$" else {
            throw DecodingError.typeMismatch(
                Bool.self,
                DecodingError.Context(codingPath: self.codingPath + [key], debugDescription: "Cannot decode tag-name as 'Int8'.")
            )
        }

        let content = try getContent(forKey: key)

        guard let result = Int8(content) else {
            throw DecodingError.typeMismatch(
                Bool.self,
                DecodingError.Context(codingPath: self.codingPath + [key], debugDescription: "Couldn't decode 'Int8'.")
            )
        }
        return result
    }

    func decode(_: UInt.Type, forKey key: Key) throws -> UInt {
        guard key.stringValue != "$" else {
            throw DecodingError.typeMismatch(
                Bool.self,
                DecodingError.Context(codingPath: self.codingPath + [key], debugDescription: "Cannot decode tag-name as 'UInt'.")
            )
        }

        let content = try getContent(forKey: key)

        guard let result = UInt(content) else {
            throw DecodingError.typeMismatch(
                Bool.self,
                DecodingError.Context(codingPath: self.codingPath + [key], debugDescription: "Couldn't decode 'UInt'.")
            )
        }
        return result
    }

    func decode(_: UInt64.Type, forKey key: Key) throws -> UInt64 {
        guard key.stringValue != "$" else {
            throw DecodingError.typeMismatch(
                Bool.self,
                DecodingError.Context(codingPath: self.codingPath + [key], debugDescription: "Cannot decode tag-name as 'UInt64'.")
            )
        }

        let content = try getContent(forKey: key)

        guard let result = UInt64(content) else {
            throw DecodingError.typeMismatch(
                Bool.self,
                DecodingError.Context(codingPath: self.codingPath + [key], debugDescription: "Couldn't decode 'UInt64'.")
            )
        }
        return result
    }

    func decode(_: UInt32.Type, forKey key: Key) throws -> UInt32 {
        guard key.stringValue != "$" else {
            throw DecodingError.typeMismatch(
                Bool.self,
                DecodingError.Context(codingPath: self.codingPath + [key], debugDescription: "Cannot decode tag-name as 'UInt32'.")
            )
        }

        let content = try getContent(forKey: key)

        guard let result = UInt32(content) else {
            throw DecodingError.typeMismatch(
                Bool.self,
                DecodingError.Context(codingPath: self.codingPath + [key], debugDescription: "Couldn't decode 'UInt32'.")
            )
        }
        return result
    }

    func decode(_: UInt16.Type, forKey key: Key) throws -> UInt16 {
        guard key.stringValue != "$" else {
            throw DecodingError.typeMismatch(
                Bool.self,
                DecodingError.Context(codingPath: self.codingPath + [key], debugDescription: "Cannot decode tag-name as 'UInt16'.")
            )
        }

        let content = try getContent(forKey: key)

        guard let result = UInt16(content) else {
            throw DecodingError.typeMismatch(
                Bool.self,
                DecodingError.Context(codingPath: self.codingPath + [key], debugDescription: "Couldn't decode 'UInt16'.")
            )
        }
        return result
    }

    func decode(_: UInt8.Type, forKey key: Key) throws -> UInt8 {
        guard key.stringValue != "$" else {
            throw DecodingError.typeMismatch(
                Bool.self,
                DecodingError.Context(codingPath: self.codingPath + [key], debugDescription: "Cannot decode tag-name as 'UInt8'.")
            )
        }

        let content = try getContent(forKey: key)

        guard let result = UInt8(content) else {
            throw DecodingError.typeMismatch(
                Bool.self,
                DecodingError.Context(codingPath: self.codingPath + [key], debugDescription: "Couldn't decode 'UInt8'.")
            )
        }
        return result
    }

    func decode(_: String.Type, forKey key: Key) throws -> String {
        guard key.stringValue != "$" else {
            return String(
                try self.decoder.xml.getTagName(of: self.decoder.tagIndex)
            )
        }

        return String(
            try getContent(forKey: key)
        )
    }

    func decode(_: Float.Type, forKey key: Key) throws -> Float {
        guard key.stringValue != "$" else {
            throw DecodingError.typeMismatch(
                Bool.self,
                DecodingError.Context(codingPath: self.codingPath + [key], debugDescription: "Cannot decode tag-name as 'Float'.")
            )
        }

        let content = try getContent(forKey: key)

        guard let result = Float(content) else {
            throw DecodingError.typeMismatch(
                Bool.self,
                DecodingError.Context(codingPath: self.codingPath + [key], debugDescription: "Couldn't decode 'Float'.")
            )
        }
        return result
    }

    func decode(_: Double.Type, forKey key: Key) throws -> Double {
        guard key.stringValue != "$" else {
            throw DecodingError.typeMismatch(
                Bool.self,
                DecodingError.Context(codingPath: self.codingPath + [key], debugDescription: "Cannot decode tag-name as 'Double'.")
            )
        }

        let content = try getContent(forKey: key)

        guard let result = Double(content) else {
            throw DecodingError.typeMismatch(
                Bool.self,
                DecodingError.Context(codingPath: self.codingPath + [key], debugDescription: "Couldn't decode 'Double'.")
            )
        }
        return result
    }

    func contains(_ key: Key) -> Bool {
        guard key.stringValue != "$" else {
            return true
        }

        guard key.stringValue != "" else {
            return !(try! self.decoder.xml.isEmpty(at: self.decoder.tagIndex))
        }

        return self.attributes.contains { $0.0 == key.stringValue }
    }

    func decodeNil(forKey key: Key) throws -> Bool {
        guard key.stringValue != "$" else {
            throw DecodingError.typeMismatch(
                Optional<Any>.self,
                DecodingError.Context(codingPath: self.codingPath + [key], debugDescription: "Cannot decode tag-name as 'Optional'.")
            )
        }

        guard key.stringValue != "" else {
            return try self.decoder.xml.isEmpty(at: self.decoder.tagIndex)
        }

        return self.attributes.contains { $0.0 == key.stringValue && $0.1 == self.decoder.options.nilLiteral }
    }

    func decode<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T {
        guard key.stringValue != "$" else {
            let decoder = XMLTagDecoder(tagContent: try self.decoder.xml.getTagName(of: self.decoder.tagIndex), codingPath: self.codingPath + [key], userInfo: self.decoder.userInfoSendable)
            return try T.init(from: decoder)
        }

        guard key.stringValue == "" else {
            guard let attribute = self.attributes.first(where: { $0.0 == key.stringValue }) else {
                throw DecodingError.keyNotFound(
                    key,
                    DecodingError.Context(codingPath: self.codingPath + [key], debugDescription: "Tag doesn't have the specified attribute to decode as 'Bool'.")
                )
            }

            let decoder = XMLAttributeDecoder(attributeValue: attribute.1, codingPath: self.codingPath + [key], userInfo: self.decoder.userInfoSendable, options: self.decoder.options)
            return try T.init(from: decoder)
        }

        if try self.decoder.xml.hasChildren(at: self.decoder.tagIndex) {
            let decoder = XMLChildrenDecoder(xml: self.decoder.xml, codingPath: self.codingPath + [key], userInfo: self.decoder.userInfoSendable, options: self.decoder.options, tagIndex: self.decoder.tagIndex)
            return try T.init(from: decoder)
        } else if try self.decoder.xml.hasContent(at: self.decoder.tagIndex) {
            fatalError("TODO")
            // let decoder = XMLContentDecoder(content: attribute.1, codingPath: self.codingPath + [key], userInfo: self.decoder.userInfoSendable)
            // return try T.init(from: decoder)
        } else {
            throw DecodingError.valueNotFound(
                T.self,
                DecodingError.Context(codingPath: self.codingPath + [key], debugDescription: "There is no children/content to decode")
            )
        }
    }

    func nestedContainer<NestedKey: CodingKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> {
        throw DecodingError.valueNotFound(
            NestedKey.self,
            DecodingError.Context(codingPath: self.codingPath + [key], debugDescription: "Unsupported decoding method 'nestedContainer' for xml container.")
        )
    }

    func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
        guard key.stringValue == "" else {
            throw DecodingError.typeMismatch(
                Array<Any>.self,
                DecodingError.Context(codingPath: self.codingPath + [key], debugDescription: "Can only decode 'nestedUnkeyedContainer' for key '' for xml container.")
            )
        }

        let decoder = XMLChildrenDecoder(xml: self.decoder.xml, codingPath: self.codingPath + [key], userInfo: self.decoder.userInfoSendable, options: self.decoder.options, tagIndex: self.decoder.tagIndex)
        return try decoder.unkeyedContainer()
    }

    func superDecoder() throws -> Decoder {
        return self.decoder
    }

    func superDecoder(forKey key: Key) throws -> Decoder {
        guard key.stringValue == "super" && key.intValue == 0 else {
            throw DecodingError.valueNotFound(
                Decoder.self,
                DecodingError.Context(codingPath: self.codingPath + [key], debugDescription: "Unsupported decoding method 'superDecoder' for xml container with key '\(key)'.")
            )
        }

        return self.decoder
    }
}

fileprivate struct XMLChildrenContainer: UnkeyedDecodingContainer {
    let decoder: XMLChildrenDecoder
    var currentIndex: Int = 0

    var codingPath: [any CodingKey] { self.decoder.codingPath + [CSVRowIndex(intValue: self.currentIndex)] }
    var count: Int? { self.decoder.childTagIndices.count }
    var isAtEnd: Bool { currentIndex >= self.decoder.childTagIndices.count }

    fileprivate struct CSVRowIndex: CodingKey {
        let intValue: Int?
        let stringValue: String

        init(intValue: Int) {
            self.intValue = intValue
            self.stringValue = "\(intValue)"
        }

        @available(*, deprecated, message: "Only present for protocol conformance")
        init(stringValue: String) {
            self.intValue = nil
            self.stringValue = stringValue
        }
    }

    mutating func decodeNil() throws -> Bool {
        throw DecodingError.valueNotFound(Never.self, DecodingError.Context(codingPath: self.codingPath, debugDescription: "Cannot decode 'nil' for tag children in xml."))
    }

    mutating func decode(_ type: Bool.Type) throws -> Bool {
        throw DecodingError.valueNotFound(Bool.self, DecodingError.Context(codingPath: self.codingPath, debugDescription: "Cannot decode 'Bool' for tag children in xml."))
    }

    mutating func decode(_ type: String.Type) throws -> String {
        throw DecodingError.valueNotFound(String.self, DecodingError.Context(codingPath: self.codingPath, debugDescription: "Cannot decode 'String' for tag children in xml."))
    }

    mutating func decode(_ type: Float.Type) throws -> Float {
        throw DecodingError.valueNotFound(Float.self, DecodingError.Context(codingPath: self.codingPath, debugDescription: "Cannot decode 'Float' for tag children in xml."))
    }

    mutating func decode(_ type: Double.Type) throws -> Double {
        throw DecodingError.valueNotFound(Double.self, DecodingError.Context(codingPath: self.codingPath, debugDescription: "Cannot decode 'Double' for tag children in xml."))
    }

    mutating func decode(_ type: Int.Type) throws -> Int {
        throw DecodingError.valueNotFound(Int.self, DecodingError.Context(codingPath: self.codingPath, debugDescription: "Cannot decode 'Int' for tag children in xml."))
    }

    mutating func decode(_ type: Int64.Type) throws -> Int64 {
        throw DecodingError.valueNotFound(Int64.self, DecodingError.Context(codingPath: self.codingPath, debugDescription: "Cannot decode 'Int64' for tag children in xml."))
    }

    mutating func decode(_ type: Int32.Type) throws -> Int32 {
        throw DecodingError.valueNotFound(Int32.self, DecodingError.Context(codingPath: self.codingPath, debugDescription: "Cannot decode 'Int32' for tag children in xml."))
    }

    mutating func decode(_ type: Int16.Type) throws -> Int16 {
        throw DecodingError.valueNotFound(Int16.self, DecodingError.Context(codingPath: self.codingPath, debugDescription: "Cannot decode 'Int16' for tag children in xml."))
    }

    mutating func decode(_ type: Int8.Type) throws -> Int8 {
        throw DecodingError.valueNotFound(Int8.self, DecodingError.Context(codingPath: self.codingPath, debugDescription: "Cannot decode 'Int8' for tag children in xml."))
    }

    mutating func decode(_ type: UInt.Type) throws -> UInt {
        throw DecodingError.valueNotFound(UInt.self, DecodingError.Context(codingPath: self.codingPath, debugDescription: "Cannot decode 'UInt' for tag children in xml."))
    }

    mutating func decode(_ type: UInt64.Type) throws -> UInt64 {
        throw DecodingError.valueNotFound(UInt64.self, DecodingError.Context(codingPath: self.codingPath, debugDescription: "Cannot decode 'UInt64' for tag children in xml."))
    }

    mutating func decode(_ type: UInt32.Type) throws -> UInt32 {
        throw DecodingError.valueNotFound(UInt32.self, DecodingError.Context(codingPath: self.codingPath, debugDescription: "Cannot decode 'UInt32' for tag children in xml."))
    }

    mutating func decode(_ type: UInt16.Type) throws -> UInt16 {
        throw DecodingError.valueNotFound(UInt16.self, DecodingError.Context(codingPath: self.codingPath, debugDescription: "Cannot decode 'UInt16' for tag children in xml."))
    }

    mutating func decode(_ type: UInt8.Type) throws -> UInt8 {
        throw DecodingError.valueNotFound(UInt8.self, DecodingError.Context(codingPath: self.codingPath, debugDescription: "Cannot decode 'UInt8' for tag children in xml."))
    }

    mutating func decode<T>(_ type: T.Type) throws -> T where T : Decodable {
        guard !isAtEnd else {
            throw DecodingError.valueNotFound(T.self, DecodingError.Context(codingPath: self.codingPath, debugDescription: "Cannot decode 'any Decodable' value because already at end"))
        }
        let decoder = XMLContainerDecoder(xml: self.decoder.xml, userInfo: self.decoder.userInfoSendable, options: self.decoder.options, tagIndex: self.decoder.childTagIndices[self.currentIndex])
        let result = try T.init(from: decoder)
        self.currentIndex += 1
        return result
    }

    mutating func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
        guard !isAtEnd else {
            throw DecodingError.valueNotFound(Decodable.self, DecodingError.Context(codingPath: self.codingPath, debugDescription: "Cannot decode 'any Decodable' value because already at end"))
        }
        let decoder = XMLContainerDecoder(xml: self.decoder.xml, userInfo: self.decoder.userInfoSendable, options: self.decoder.options, tagIndex: self.decoder.childTagIndices[self.currentIndex])
        self.currentIndex += 1
        return KeyedDecodingContainer(XMLContainer<NestedKey>(decoder: decoder))
    }

    mutating func nestedUnkeyedContainer() throws -> any UnkeyedDecodingContainer {
        throw DecodingError.valueNotFound(
            Array<Array<any Decodable>>.self,
            DecodingError.Context(codingPath: self.codingPath, debugDescription: "Unsupported decoding method 'nestedUnkeyedContainer' for tag children in xml.")
        )
    }

    func superDecoder() throws -> Decoder {
        return self.decoder
    }
}

fileprivate class XMLTagDecoder: Decoder {
    let tagContent: Substring
    let codingPath: [any CodingKey]

    let userInfoSendable: [CodingUserInfoKey: Sendable]
    var userInfo: [CodingUserInfoKey: Any] { self.userInfoSendable }

    init(tagContent: Substring, codingPath: [any CodingKey], userInfo userInfoSendable: [CodingUserInfoKey: Sendable]) {
        self.tagContent = tagContent
        self.codingPath = codingPath
        self.userInfoSendable = userInfoSendable
    }

    func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> where Key : CodingKey {
        throw DecodingError.typeMismatch(String.self, DecodingError.Context(codingPath: self.codingPath, debugDescription: "Expected to decode single 'String' value for tag not 'container'"))
    }

    func unkeyedContainer() throws -> any UnkeyedDecodingContainer {
        throw DecodingError.typeMismatch(String.self, DecodingError.Context(codingPath: self.codingPath, debugDescription: "Expected to decode single 'String' value for tag not 'unkeyedContainer'"))
    }

    func singleValueContainer() throws -> any SingleValueDecodingContainer {
        return XMLTagContainer(decoder: self, codingPath: self.codingPath)
    }
}

fileprivate struct XMLTagContainer: SingleValueDecodingContainer {
    let decoder: XMLTagDecoder
    let codingPath: [any CodingKey]

    func decode<T>(_ type: T.Type) throws -> T where T : Decodable {
        return try T.init(from: self.decoder)
    }

    func decodeNil() -> Bool {
        return false
    }

    func decode(_ type: Bool.Type) throws -> Bool {
        throw DecodingError.typeMismatch(String.self, DecodingError.Context(codingPath: self.codingPath, debugDescription: "Expected to decode single 'String' value for tag not 'Bool'"))
    }

    func decode(_ type: Float.Type) throws -> Float {
        throw DecodingError.typeMismatch(String.self, DecodingError.Context(codingPath: self.codingPath, debugDescription: "Expected to decode single 'String' value for tag not 'Float'"))
    }

    func decode(_ type: Double.Type) throws -> Double {
        throw DecodingError.typeMismatch(String.self, DecodingError.Context(codingPath: self.codingPath, debugDescription: "Expected to decode single 'String' value for tag not 'Double'"))
    }

    func decode(_ type: Int.Type) throws -> Int {
        throw DecodingError.typeMismatch(String.self, DecodingError.Context(codingPath: self.codingPath, debugDescription: "Expected to decode single 'String' value for tag not 'Int'"))
    }

    func decode(_ type: Int64.Type) throws -> Int64 {
        throw DecodingError.typeMismatch(String.self, DecodingError.Context(codingPath: self.codingPath, debugDescription: "Expected to decode single 'String' value for tag not 'Int64'"))
    }

    func decode(_ type: Int32.Type) throws -> Int32 {
        throw DecodingError.typeMismatch(String.self, DecodingError.Context(codingPath: self.codingPath, debugDescription: "Expected to decode single 'String' value for tag not 'Int32'"))
    }

    func decode(_ type: Int16.Type) throws -> Int16 {
        throw DecodingError.typeMismatch(String.self, DecodingError.Context(codingPath: self.codingPath, debugDescription: "Expected to decode single 'String' value for tag not 'Int16'"))
    }

    func decode(_ type: Int8.Type) throws -> Int8 {
        throw DecodingError.typeMismatch(String.self, DecodingError.Context(codingPath: self.codingPath, debugDescription: "Expected to decode single 'String' value for tag not 'Int8'"))
    }

    func decode(_ type: UInt.Type) throws -> UInt {
        throw DecodingError.typeMismatch(String.self, DecodingError.Context(codingPath: self.codingPath, debugDescription: "Expected to decode single 'String' value for tag not 'UInt'"))
    }

    func decode(_ type: UInt64.Type) throws -> UInt64 {
        throw DecodingError.typeMismatch(String.self, DecodingError.Context(codingPath: self.codingPath, debugDescription: "Expected to decode single 'String' value for tag not 'UInt64'"))
    }

    func decode(_ type: UInt32.Type) throws -> UInt32 {
        throw DecodingError.typeMismatch(String.self, DecodingError.Context(codingPath: self.codingPath, debugDescription: "Expected to decode single 'String' value for tag not 'UInt32'"))
    }

    func decode(_ type: UInt16.Type) throws -> UInt16 {
        throw DecodingError.typeMismatch(String.self, DecodingError.Context(codingPath: self.codingPath, debugDescription: "Expected to decode single 'String' value for tag not 'UInt16'"))
    }

    func decode(_ type: UInt8.Type) throws -> UInt8 {
        throw DecodingError.typeMismatch(String.self, DecodingError.Context(codingPath: self.codingPath, debugDescription: "Expected to decode single 'String' value for tag not 'UInt8'"))
    }

    func decode(_ type: String.Type) throws -> String {
        return String(self.decoder.tagContent)
    }
}

fileprivate class XMLAttributeDecoder: Decoder {
    let attributeValue: Substring
    let options: XMLDecoderOptions
    let codingPath: [any CodingKey]

    let userInfoSendable: [CodingUserInfoKey: Sendable]
    var userInfo: [CodingUserInfoKey: Any] { self.userInfoSendable }

    init(attributeValue: Substring, codingPath: [any CodingKey], userInfo userInfoSendable: [CodingUserInfoKey: Sendable], options: XMLDecoderOptions) {
        self.attributeValue = attributeValue
        self.codingPath = codingPath
        self.userInfoSendable = userInfoSendable
        self.options = options
    }

    func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> where Key : CodingKey {
        throw DecodingError.typeMismatch(String.self, DecodingError.Context(codingPath: self.codingPath, debugDescription: "Expected to decode single 'String' value for tag not 'container'"))
    }

    func unkeyedContainer() throws -> any UnkeyedDecodingContainer {
        throw DecodingError.typeMismatch(String.self, DecodingError.Context(codingPath: self.codingPath, debugDescription: "Expected to decode single 'String' value for tag not 'unkeyedContainer'"))
    }

    func singleValueContainer() throws -> any SingleValueDecodingContainer {
        return XMLAttributeContainer(decoder: self, codingPath: self.codingPath)
    }
}

fileprivate struct XMLAttributeContainer: SingleValueDecodingContainer {
    let decoder: XMLAttributeDecoder
    let codingPath: [any CodingKey]

    func decode<T>(_ type: T.Type) throws -> T where T : Decodable {
        return try T.init(from: self.decoder)
    }

    func decodeNil() -> Bool {
        return self.decoder.attributeValue == self.decoder.options.nilLiteral
    }

    func decode(_ type: Bool.Type) throws -> Bool {
        if self.decoder.attributeValue == self.decoder.options.trueLiteral {
            return true
        } else if self.decoder.attributeValue == self.decoder.options.falseLiteral {
            return false
        } else {
            throw DecodingError.typeMismatch(
                Bool.self,
                DecodingError.Context(codingPath: self.codingPath, debugDescription: "Couldn't decode 'Bool'.")
            )
        }
    }

    func decode(_ type: Float.Type) throws -> Float {
        guard let result = Float(self.decoder.attributeValue) else {
            throw DecodingError.typeMismatch(
                Float.self,
                DecodingError.Context(codingPath: self.codingPath, debugDescription: "Couldn't decode 'Float'.")
            )
        }
        return result
    }

    func decode(_ type: Double.Type) throws -> Double {
        guard let result = Double(self.decoder.attributeValue) else {
            throw DecodingError.typeMismatch(
                Double.self,
                DecodingError.Context(codingPath: self.codingPath, debugDescription: "Couldn't decode 'Double'.")
            )
        }
        return result
    }

    func decode(_ type: Int.Type) throws -> Int {
        guard let result = Int(self.decoder.attributeValue) else {
            throw DecodingError.typeMismatch(
                Int.self,
                DecodingError.Context(codingPath: self.codingPath, debugDescription: "Couldn't decode 'Int'.")
            )
        }
        return result
    }

    func decode(_ type: Int64.Type) throws -> Int64 {
        guard let result = Int64(self.decoder.attributeValue) else {
            throw DecodingError.typeMismatch(
                Int64.self,
                DecodingError.Context(codingPath: self.codingPath, debugDescription: "Couldn't decode 'Int64'.")
            )
        }
        return result
    }

    func decode(_ type: Int32.Type) throws -> Int32 {
        guard let result = Int32(self.decoder.attributeValue) else {
            throw DecodingError.typeMismatch(
                Int32.self,
                DecodingError.Context(codingPath: self.codingPath, debugDescription: "Couldn't decode 'Int32'.")
            )
        }
        return result
    }

    func decode(_ type: Int16.Type) throws -> Int16 {
        guard let result = Int16(self.decoder.attributeValue) else {
            throw DecodingError.typeMismatch(
                Int16.self,
                DecodingError.Context(codingPath: self.codingPath, debugDescription: "Couldn't decode 'Int16'.")
            )
        }
        return result
    }

    func decode(_ type: Int8.Type) throws -> Int8 {
        guard let result = Int8(self.decoder.attributeValue) else {
            throw DecodingError.typeMismatch(
                Int8.self,
                DecodingError.Context(codingPath: self.codingPath, debugDescription: "Couldn't decode 'Int8'.")
            )
        }
        return result
    }

    func decode(_ type: UInt.Type) throws -> UInt {
        guard let result = UInt(self.decoder.attributeValue) else {
            throw DecodingError.typeMismatch(
                UInt.self,
                DecodingError.Context(codingPath: self.codingPath, debugDescription: "Couldn't decode 'UInt'.")
            )
        }
        return result
    }

    func decode(_ type: UInt64.Type) throws -> UInt64 {
        guard let result = UInt64(self.decoder.attributeValue) else {
            throw DecodingError.typeMismatch(
                UInt64.self,
                DecodingError.Context(codingPath: self.codingPath, debugDescription: "Couldn't decode 'UInt64'.")
            )
        }
        return result
    }

    func decode(_ type: UInt32.Type) throws -> UInt32 {
        guard let result = UInt32(self.decoder.attributeValue) else {
            throw DecodingError.typeMismatch(
                UInt32.self,
                DecodingError.Context(codingPath: self.codingPath, debugDescription: "Couldn't decode 'UInt32'.")
            )
        }
        return result
    }

    func decode(_ type: UInt16.Type) throws -> UInt16 {
        guard let result = UInt16(self.decoder.attributeValue) else {
            throw DecodingError.typeMismatch(
                UInt16.self,
                DecodingError.Context(codingPath: self.codingPath, debugDescription: "Couldn't decode 'UInt16'.")
            )
        }
        return result
    }

    func decode(_ type: UInt8.Type) throws -> UInt8 {
        guard let result = UInt8(self.decoder.attributeValue) else {
            throw DecodingError.typeMismatch(
                UInt8.self,
                DecodingError.Context(codingPath: self.codingPath, debugDescription: "Couldn't decode 'UInt8'.")
            )
        }
        return result
    }

    func decode(_ type: String.Type) throws -> String {
        return String(self.decoder.attributeValue)
    }
}

fileprivate class XMLChildrenDecoder: Decoder {
    let xml: ParsedXML
    let codingPath: [any CodingKey]
    let options: XMLDecoderOptions
    let userInfoSendable: [CodingUserInfoKey : Sendable]
    let childTagIndices: [Int]
    var userInfo: [CodingUserInfoKey : Any] { self.userInfoSendable }

    init(xml: ParsedXML, codingPath: [any CodingKey], userInfo userInfoSendable: [CodingUserInfoKey: Sendable], options: XMLDecoderOptions, tagIndex: Int) {
        self.xml = xml
        self.codingPath = codingPath
        self.userInfoSendable = userInfoSendable
        self.options = options
        self.childTagIndices = try! xml.getChildren(of: tagIndex)
    }

    func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> where Key : CodingKey {
        throw DecodingError.typeMismatch(String.self, DecodingError.Context(codingPath: self.codingPath, debugDescription: "Expected to decode single 'String' value for tag not 'container'"))
    }

    func unkeyedContainer() throws -> any UnkeyedDecodingContainer {
        return XMLChildrenContainer(decoder: self)
    }

    func singleValueContainer() throws -> any SingleValueDecodingContainer {
        throw DecodingError.typeMismatch(String.self, DecodingError.Context(codingPath: self.codingPath, debugDescription: "Expected to decode single 'String' value for tag not 'unkeyedContainer'"))
    }
}

fileprivate class XMLContentDecoder: Decoder {
    let contentValue: Substring
    let options: XMLDecoderOptions
    let codingPath: [any CodingKey]

    let userInfoSendable: [CodingUserInfoKey: Sendable]
    var userInfo: [CodingUserInfoKey: Any] { self.userInfoSendable }

    init(contentValue: Substring, codingPath: [any CodingKey], userInfo userInfoSendable: [CodingUserInfoKey: Sendable], options: XMLDecoderOptions) {
        self.contentValue = contentValue
        self.codingPath = codingPath
        self.userInfoSendable = userInfoSendable
        self.options = options
    }

    func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> where Key : CodingKey {
        throw DecodingError.typeMismatch(String.self, DecodingError.Context(codingPath: self.codingPath, debugDescription: "Expected to decode single 'String' value for tag not 'container'"))
    }

    func unkeyedContainer() throws -> any UnkeyedDecodingContainer {
        throw DecodingError.typeMismatch(String.self, DecodingError.Context(codingPath: self.codingPath, debugDescription: "Expected to decode single 'String' value for tag not 'unkeyedContainer'"))
    }

    func singleValueContainer() throws -> any SingleValueDecodingContainer {
        fatalError("TODO")
    }
}
