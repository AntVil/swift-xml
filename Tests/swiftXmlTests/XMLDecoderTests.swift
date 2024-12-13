import XCTest

@testable import swiftXml

public final class XMLDecoderTests: XCTestCase {
    func testDecodeAttributes() throws {
        let xml = """
        <root a="1" b="2" c="3"></root>
        """

        struct XML: Decodable {
            let a: Int
            let b: Int
            let c: Int
        }

        let decoder = XMLDecoder()

        let result = try decoder.decode(XML.self, from: xml)

        XCTAssertEqual(result.a, 1)
        XCTAssertEqual(result.b, 2)
        XCTAssertEqual(result.c, 3)
    }

    func testDecodeTag() throws {
        let xml = """
        <root></root>
        """

        struct XML: Decodable {
            let tag: String

            enum CodingKeys: String, CodingKey {
                case tag = "$"
            }
        }

        let decoder = XMLDecoder()

        let result = try decoder.decode(XML.self, from: xml)

        XCTAssertEqual(result.tag, "root")
    }

    func testDecodeContent() throws {
        let xml = """
        <root>some content</root>
        """

        struct XML: Decodable {
            let content: String

            enum CodingKeys: String, CodingKey {
                case content = ""
            }
        }

        let decoder = XMLDecoder()

        let result = try decoder.decode(XML.self, from: xml)

        XCTAssertEqual(result.content, "some content")
    }

    func testDecodeChildren() throws {
        let xml = """
        <root>
            <child1 empty="false">123</child1>
            <child2 empty="true" />
            <child3 empty = "false">
                789
            </child3>
        </root>
        """

        struct XML: Decodable {
            let children: [Children]

            enum CodingKeys: String, CodingKey {
                case children = ""
            }

            struct Children: Decodable {
                let tag: String
                let content: Int?
                let empty: Bool

                enum CodingKeys: String, CodingKey {
                    case tag = "$"
                    case content = ""
                    case empty
                }
            }
        }

        let decoder = XMLDecoder()

        let result = try decoder.decode(XML.self, from: xml)

        XCTAssertEqual(result.children.map { $0.tag }, ["child1", "child2", "child3"])
        XCTAssertEqual(result.children.map { $0.content }, [123, nil, 789])
        XCTAssertEqual(result.children.map { $0.empty }, [false, true, false])
    }

    func testDecodeWrappedContentDecodable() throws {
        let xml = """
        <root>
            uppercase
        </root>
        """

        struct XML: Decodable {
            let content: UppercaseString

            enum CodingKeys: String, CodingKey {
                case content = ""
            }

            struct UppercaseString: Decodable {
                let content: String

                init(from decoder: Decoder) throws {
                    let container = try decoder.singleValueContainer()
                    self.content = try container.decode(String.self).uppercased()
                }
            }
        }

        let decoder = XMLDecoder()

        let result = try decoder.decode(XML.self, from: xml)

        XCTAssertEqual(result.content.content, "UPPERCASE")
    }

    func testDecodeWrappedAttributeDecodable() throws {
        let xml = """
        <root content="uppercase" />
        """

        struct XML: Decodable {
            let content: UppercaseString

            enum CodingKeys: String, CodingKey {
                case content
            }

            struct UppercaseString: Decodable {
                let content: String

                init(from decoder: Decoder) throws {
                    let container = try decoder.singleValueContainer()
                    self.content = try container.decode(String.self).uppercased()
                }
            }
        }

        let decoder = XMLDecoder()

        let result = try decoder.decode(XML.self, from: xml)

        XCTAssertEqual(result.content.content, "UPPERCASE")
    }
}
