//
//  MarkdownToChunksTests.swift
//  AtomAIAssistantTests
//
//  Created by Gowtham, Namuru on 08/02/26.
//

import XCTest
@testable import AtomAIAssistant

final class MarkdownToChunksTests: XCTestCase {

    func test_shouldLoad_withHeadings() throws {
        let markdown = try XCTUnwrap(String.loadMarkdown(from: "sampleWithHeadingAndSubSection"), "Expected to load data from sampleWithHeadingAndSubSection.md file")
        let chunks = MarkdownToChunks.generateChunks(from: markdown, docName: "sampleWithHeadingAndSubSection")
        
        let expectedChunks = [ParsedChunk(docName: "sampleWithHeadingAndSubSection", page: 1, headerPath: ["ACCESSORIES FOR iPADS (COUPA)", "COUPA ORDERING INSTRUCTIONS NOTE: Please contact your local leadership for approval to order the following accessories."], kind: .text, text: "Open Coupa (https://aa.coupahost.com/user/home) and scroll to the bottom of the Home Page to get to the Additional Stores section on the right-hand side of the page.")]

        XCTAssertEqual(chunks, expectedChunks, "Expected \(expectedChunks), but got \(chunks)")
    }

    func test_shouldLoad_Tables() throws {
        let markdown = try XCTUnwrap(String.loadMarkdown(from: "sampleTableCommonHeading"), "Expected to load data from sampleWithTable.md file")
        let chunks = MarkdownToChunks.generateChunks(from: markdown, docName: "sampleTableCommonHeading")
        
        let expectedChunks = [ParsedChunk(docName: "sampleTableCommonHeading", page: 1, headerPath: ["ACCESSORIES FOR iPADS (COUPA)", "COUPA ORDERING INSTRUCTIONS NOTE: Please contact your local leadership for approval to order the following accessories"], kind: .tableRow, tableName: "COUPA ORDERING INSTRUCTIONS NOTE: Please contact your local leadership for approval to order the following accessories", columns: ["If the order has been:", "Converted in Coupa"], rowValues: ["If the order has been:": "Fully Invoiced", "Converted in Coupa": "Yes"]), ParsedChunk(docName: "sampleTableCommonHeading", page: 1, headerPath: ["ACCESSORIES FOR iPADS (COUPA)", "COUPA ORDERING INSTRUCTIONS NOTE: Please contact your local leadership for approval to order the following accessories"], kind: .tableRow, tableName: "COUPA ORDERING INSTRUCTIONS NOTE: Please contact your local leadership for approval to order the following accessories", columns: ["If the order has been:", "Converted in Coupa"], rowValues: ["If the order has been:": "Partially Invoiced", "Converted in Coupa": "Yes"])].map({ $0.formattedTableString })
        XCTAssertEqual(chunks.map { $0.formattedTableString }, expectedChunks, "Expected \(expectedChunks), but got \(chunks)")
    }

    func test_shouldLoad_tableWithDifferentSections() throws {
        let markdown = try XCTUnwrap(String.loadMarkdown(from: "sampleTableDifferentHeading"), "Expected to load data from sampleWithTable.md file")
        let chunks = MarkdownToChunks.generateChunks(from: markdown, docName: "sampleTableDifferentHeading")
        
        let expectedChunks: [String] = ["ACCESSORIES FOR iPADS (COUPA)/iPAD ACCESSORY OPTIONS/APPLE POWER ADAPTER (GEN 7, 8, 9 iPADS) - APPLE POWER ADAPTER (GEN 7, 8, 9 iPADS) - DESCRIPTION: 12W USB Power Adapter for iPad PART NUMBER: MGN03AM/A PICTURE: L PRICE: $15.54"]
        XCTAssertEqual(chunks.map { $0.formattedTableString }, expectedChunks)
    }

    func test_shouldLoad_withNotices() throws {
        let markdown = try XCTUnwrap(String.loadMarkdown(from: "sampleNotices"), "Expected to load data from sampleNotices.md file")
        let chunks = MarkdownToChunks.generateChunks(from: markdown, docName: "sampleNotices")
        
        let expectedChunk = [ParsedChunk(docName: "sampleNotices", page: 1, headerPath: ["ACCESSORIES FOR iPADS (COUPA)", "COUPA ORDERING INSTRUCTIONS"], kind: .notice, notice: Notice(severity: .note, title: "Note", message: "Please contact your local leadership for approval to order the following accessories")), ParsedChunk(docName: "sampleNotices", page: 1, headerPath: ["ACCESSORIES FOR iPADS (COUPA)", "COUPA ORDERING INSTRUCTIONS"], kind: .notice, notice: Notice(severity: .warning, title: "Warning", message: "This is a warning"))]
        
        XCTAssertEqual(chunks, expectedChunk)
    }
}


// MARK: - HeadingPaths
extension MarkdownToChunksTests {
    func test_levels_of_headings() {
        var headingPath = HeadingPath()
        
        headingPath.set(level: 1, title: "First heading")
        headingPath.set(level: 2, title: "Second heading")
        
        XCTAssert(headingPath.levels == ["First heading", "Second heading"], "Expected \(headingPath.levels)")
    }
    
    func test_levelsOfHeadings_whenHeadingLevelIsOne() {
        var headingPath = HeadingPath()
        
        headingPath.set(level: 2, title: "Second heading")
        headingPath.set(level: 1, title: "First heading")
        
        // Main heading will be remained.
        XCTAssert(headingPath.levels == ["First heading"], "Expected \(headingPath.levels)")
    }

    func test_levelsOfHeading_whenHeadingIsMissing() {
        var headingPath = HeadingPath()
        
        headingPath.set(level: 1, title: "First heading")
        
        headingPath.set(level: 3, title: "Third heading")
        // Main heading will be remained.
        XCTAssert(headingPath.levels == ["First heading", "Untitled", "Third heading"], "Expected \(headingPath.levels)")
    }
}

private extension String {
    static func loadMarkdown(from fileName: String) -> String? {
        guard let url = Bundle(for: MarkdownToChunksTests.self).url(forResource: fileName, withExtension: "md") else {
            return nil
        }
        let extractedText = try? String(contentsOf: url, encoding: .utf8)
        return extractedText
    }
}
