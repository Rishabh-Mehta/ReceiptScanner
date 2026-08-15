//
//  RowClustererTests.swift
//
//  Part 4 of the native receipt scanner build plan — unit tests for clusterRows.
//  Add this file to your test target (not the app target).
//

import XCTest
@testable import ReceiptScannerKit

final class RowClustererTests: XCTestCase {

    private func line(
        _ text: String,
        x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat,
        confidence: Float = 0.9
    ) -> OCRLine {
        OCRLine(text: text, boundingBox: CGRect(x: x, y: y, width: w, height: h), confidence: confidence)
    }

    func testEmptyInputReturnsEmptyOutput() {
        XCTAssertEqual(clusterRows([]), [])
    }

    func testSingleLineIsItsOwnRow() {
        let single = line("STORE NAME", x: 0.1, y: 0.90, w: 0.4, h: 0.04)
        let rows = clusterRows([single])
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].map(\.text), ["STORE NAME"])
    }

    /// The core case this file exists for: a name and its price recognized as two
    /// separate Vision observations at (roughly) the same height should merge
    /// into one row, ordered name-then-price left-to-right.
    func testSplitLineMergesIntoOneRowOrderedLeftToRight() {
        let price = line("$2.49", x: 0.75, y: 0.605, w: 0.15, h: 0.025)
        let name = line("Organic Bananas", x: 0.05, y: 0.60, w: 0.35, h: 0.03)

        // Deliberately passed in reverse (price before name) — clustering must
        // not depend on input order.
        let rows = clusterRows([price, name])

        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].map(\.text), ["Organic Bananas", "$2.49"])
    }

    func testDistinctRowsStaySeparateAndSortTopToBottom() {
        let bananaName = line("Organic Bananas", x: 0.05, y: 0.60, w: 0.35, h: 0.03)
        let bananaPrice = line("$2.49", x: 0.75, y: 0.605, w: 0.15, h: 0.025)
        let milkName = line("Milk 1 Gal", x: 0.05, y: 0.50, w: 0.30, h: 0.03)
        let milkPrice = line("$3.99", x: 0.75, y: 0.502, w: 0.15, h: 0.028)
        let breadName = line("Bread", x: 0.05, y: 0.40, w: 0.20, h: 0.03)
        let breadPrice = line("$4.29", x: 0.75, y: 0.403, w: 0.15, h: 0.026)

        // Shuffled input order on purpose.
        let rows = clusterRows([milkPrice, breadName, bananaName, breadPrice, bananaPrice, milkName])

        XCTAssertEqual(rows.count, 3)
        XCTAssertEqual(rows[0].map(\.text), ["Organic Bananas", "$2.49"]) // topmost (highest Y)
        XCTAssertEqual(rows[1].map(\.text), ["Milk 1 Gal", "$3.99"])
        XCTAssertEqual(rows[2].map(\.text), ["Bread", "$4.29"])           // bottommost (lowest Y)
    }

    /// Confirms the Y-overlap threshold is genuinely tunable: the same two lines
    /// merge or split depending on the threshold passed in.
    func testYOverlapThresholdIsTunable() {
        // lineA: y range [0.50, 0.54]  (height 0.04)
        let lineA = line("A", x: 0.05, y: 0.50, w: 0.2, h: 0.04)
        // lineB: y range [0.525, 0.565] (height 0.04)
        // Overlap with lineA = [0.525, 0.54] = 0.015 → ratio = 0.015/0.04 = 0.375
        let lineB = line("B", x: 0.3, y: 0.525, w: 0.2, h: 0.04)

        let strictRows = clusterRows([lineA, lineB], yOverlapThreshold: 0.5)
        XCTAssertEqual(strictRows.count, 2, "0.375 overlap should NOT merge at threshold 0.5")

        let looseRows = clusterRows([lineA, lineB], yOverlapThreshold: 0.3)
        XCTAssertEqual(looseRows.count, 1, "0.375 overlap SHOULD merge at threshold 0.3")
    }

    func testExactlyAtThresholdMerges() {
        // lineC: y range [0.50, 0.54] (height 0.04)
        let lineC = line("C", x: 0.05, y: 0.50, w: 0.2, h: 0.04)
        // lineD: y range [0.52, 0.56] (height 0.04)
        // Overlap = [0.52, 0.54] = 0.02 → ratio = 0.02/0.04 = 0.5 exactly
        let lineD = line("D", x: 0.3, y: 0.52, w: 0.2, h: 0.04)

        let rows = clusterRows([lineC, lineD], yOverlapThreshold: 0.5)
        XCTAssertEqual(rows.count, 1, "Ratio exactly equal to the threshold should merge (>=, not >)")
    }
}
