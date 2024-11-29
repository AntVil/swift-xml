import XCTest

@testable import swiftXml

public final class ParsedXMLTests: XCTestCase {
    func testParseDeclaration() throws {
        let xml = """
        <? version="1.0" encoding="UTF-8" standalone="yes" ?>
        <root></root>
        """

        let parsedXml = try ParsedXML(from: xml)

        let attributes = try parsedXml.getTagAttributes(of: 0)
        let keys = attributes.map { $0.0 }
        let values = attributes.map { $0.1 }

        XCTAssertTrue(try parsedXml.isEmpty(at: 0))
        XCTAssertEqual(keys, [])
        XCTAssertEqual(values, [])
    }

    func testParseNested() throws {
        let xml = """
        <root att1="abc" att2 = 'def'>
            <child1 att="val"></child1>
            <child2 att="val"></child2>
            <child3 att="val"></child3>
        </root>
        """

        let parsedXml = try ParsedXML(from: xml)

        let attributes = try parsedXml.getTagAttributes(of: 0)
        let keys = attributes.map { $0.0 }
        let values = attributes.map { $0.1 }

        XCTAssertTrue(try parsedXml.hasChildren(at: 0))
        XCTAssertEqual(try parsedXml.getChildren(of: 0), [6, 10, 14])
        XCTAssertEqual(keys, ["att1", "att2"])
        XCTAssertEqual(values, ["abc", "def"])
    }

    func testParseSingleTag() throws {
        let xml = """
        <tag></tag>
        """

        let parsedXml = try ParsedXML(from: xml)

        let attributes = try parsedXml.getTagAttributes(of: 0)
        let keys = attributes.map { $0.0 }
        let values = attributes.map { $0.1 }

        XCTAssertTrue(try parsedXml.isEmpty(at: 0))
        XCTAssertEqual(keys, [])
        XCTAssertEqual(values, [])
    }

    func testParseSingleTagWithNewLine() throws {
        let xml = """
        <tag></tag>

        """

        let parsedXml = try ParsedXML(from: xml)

        let attributes = try parsedXml.getTagAttributes(of: 0)
        let keys = attributes.map { $0.0 }
        let values = attributes.map { $0.1 }

        XCTAssertTrue(try parsedXml.isEmpty(at: 0))
        XCTAssertEqual(keys, [])
        XCTAssertEqual(values, [])
    }

    func testParseSingleEmptyTag() throws {
        let xml = """
        <tag />
        """

        let parsedXml = try ParsedXML(from: xml)

        let attributes = try parsedXml.getTagAttributes(of: 0)
        let keys = attributes.map { $0.0 }
        let values = attributes.map { $0.1 }

        XCTAssertTrue(try parsedXml.isEmpty(at: 0))
        XCTAssertEqual(keys, [])
        XCTAssertEqual(values, [])
    }

    func testParseSingleTimmedEmptyTag() throws {
        let xml = """
        <tag/>
        """

        let parsedXml = try ParsedXML(from: xml)

        let attributes = try parsedXml.getTagAttributes(of: 0)
        let keys = attributes.map { $0.0 }
        let values = attributes.map { $0.1 }

        XCTAssertTrue(try parsedXml.isEmpty(at: 0))
        XCTAssertEqual(keys, [])
        XCTAssertEqual(values, [])
    }

    func testParseSingleTagWithAttribute() throws {
        let xml = """
        <tag attribute="value"></tag>
        """

        let parsedXml = try ParsedXML(from: xml)

        let attributes = try parsedXml.getTagAttributes(of: 0)
        let keys = attributes.map { $0.0 }
        let values = attributes.map { $0.1 }

        XCTAssertTrue(try parsedXml.isEmpty(at: 0))
        XCTAssertEqual(keys, ["attribute"])
        XCTAssertEqual(values, ["value"])
    }

    func testParseSingleTagWithNewLineWithAttribute() throws {
        let xml = """
        <tag attribute="value"></tag>

        """

        let parsedXml = try ParsedXML(from: xml)

        let attributes = try parsedXml.getTagAttributes(of: 0)
        let keys = attributes.map { $0.0 }
        let values = attributes.map { $0.1 }

        XCTAssertTrue(try parsedXml.isEmpty(at: 0))
        XCTAssertEqual(keys, ["attribute"])
        XCTAssertEqual(values, ["value"])
    }

    func testParseSingleEmptyTagWithAttribute() throws {
        let xml = """
        <tag attribute="value" />
        """

        let parsedXml = try ParsedXML(from: xml)

        let attributes = try parsedXml.getTagAttributes(of: 0)
        let keys = attributes.map { $0.0 }
        let values = attributes.map { $0.1 }

        XCTAssertTrue(try parsedXml.isEmpty(at: 0))
        XCTAssertEqual(keys, ["attribute"])
        XCTAssertEqual(values, ["value"])
    }

    func testParseSingleTimmedEmptyTagWithAttribute() throws {
        let xml = """
        <tag attribute="value"/>
        """

        let parsedXml = try ParsedXML(from: xml)

        let attributes = try parsedXml.getTagAttributes(of: 0)
        let keys = attributes.map { $0.0 }
        let values = attributes.map { $0.1 }

        XCTAssertTrue(try parsedXml.isEmpty(at: 0))
        XCTAssertFalse(try parsedXml.hasChildren(at: 0))
        XCTAssertFalse(try parsedXml.hasContent(at: 0))
        XCTAssertEqual(keys, ["attribute"])
        XCTAssertEqual(values, ["value"])
    }


    func testParseSingleTagWithEmptyAttribute() throws {
        let xml = """
        <tag attribute="value"></tag>
        """

        let parsedXml = try ParsedXML(from: xml)

        let attributes = try parsedXml.getTagAttributes(of: 0)
        let keys = attributes.map { $0.0 }
        let values = attributes.map { $0.1 }

        XCTAssertTrue(try parsedXml.isEmpty(at: 0))
        XCTAssertEqual(keys, ["attribute"])
        XCTAssertEqual(values, ["value"])
    }

    func testParseSingleTagWithNewLineWithEmptyAttribute() throws {
        let xml = """
        <tag attribute=""></tag>

        """

        let parsedXml = try ParsedXML(from: xml)

        let attributes = try parsedXml.getTagAttributes(of: 0)
        let keys = attributes.map { $0.0 }
        let values = attributes.map { $0.1 }

        XCTAssertTrue(try parsedXml.isEmpty(at: 0))
        XCTAssertEqual(keys, ["attribute"])
        XCTAssertEqual(values, [""])
    }

    func testParseSingleEmptyTagWithEmptyAttribute() throws {
        let xml = """
        <tag attribute="" />
        """

        let parsedXml = try ParsedXML(from: xml)

        let attributes = try parsedXml.getTagAttributes(of: 0)
        let keys = attributes.map { $0.0 }
        let values = attributes.map { $0.1 }

        XCTAssertTrue(try parsedXml.isEmpty(at: 0))
        XCTAssertEqual(keys, ["attribute"])
        XCTAssertEqual(values, [""])
    }

    func testParseSingleTimmedEmptyTagWithEmptyAttribute() throws {
        let xml = """
        <tag attribute=""/>
        """

        let parsedXml = try ParsedXML(from: xml)

        let attributes = try parsedXml.getTagAttributes(of: 0)
        let keys = attributes.map { $0.0 }
        let values = attributes.map { $0.1 }

        XCTAssertTrue(try parsedXml.isEmpty(at: 0))
        XCTAssertEqual(keys, ["attribute"])
        XCTAssertEqual(values, [""])
    }

    func testParseSingleTagWithNewLineWithEscapedAttribute() throws {
        let xml = """
        <tag attribute="\\""></tag>

        """

        let parsedXml = try ParsedXML(from: xml)

        let attributes = try parsedXml.getTagAttributes(of: 0)
        let keys = attributes.map { $0.0 }
        let values = attributes.map { $0.1 }

        XCTAssertTrue(try parsedXml.isEmpty(at: 0))
        XCTAssertEqual(keys, ["attribute"])
        // TODO: process escaped values
        // XCTAssertEqual(values, ["\""])
    }

    func testParseSingleEmptyTagWithEscapedAttribute() throws {
        let xml = """
        <tag attribute="\\"" />
        """

        let parsedXml = try ParsedXML(from: xml)

        let attributes = try parsedXml.getTagAttributes(of: 0)
        let keys = attributes.map { $0.0 }
        let values = attributes.map { $0.1 }

        XCTAssertTrue(try parsedXml.isEmpty(at: 0))
        XCTAssertEqual(keys, ["attribute"])
        // TODO: process escaped values
        // XCTAssertEqual(values, ["\""])
    }

    func testParseSingleTimmedEmptyTagWithEscapedAttribute() throws {
        let xml = """
        <tag attribute="\\""/>
        """

        let parsedXml = try ParsedXML(from: xml)

        let attributes = try parsedXml.getTagAttributes(of: 0)
        let keys = attributes.map { $0.0 }
        let values = attributes.map { $0.1 }

        XCTAssertTrue(try parsedXml.isEmpty(at: 0))
        XCTAssertEqual(keys, ["attribute"])
        // TODO: process escaped values
        // XCTAssertEqual(values, ["\""])
    }
}
