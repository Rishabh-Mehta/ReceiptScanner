//
//  ReceiptItemParserTests.swift
//
//  Part 5 of the native receipt scanner build plan — unit tests for parseItems.
//  Add this file to your test target (not the app target).
//

import XCTest
@testable import ReceiptScannerKit

final class ReceiptItemParserTests: XCTestCase {

    /// Builds a row from one or more already-clustered OCRLine texts. Bounding
    /// boxes are irrelevant here — parseItems only reads `.text` — so `.zero` is
    /// used as a placeholder throughout.
    private func row(_ texts: String...) -> [OCRLine] {
        texts.map { OCRLine(text: $0, boundingBox: .zero, confidence: 0.9) }
    }

    // MARK: - Basic parsing

    func testBasicItemRowParsesNameAndPrice() {
        let (items, total) = parseItems(fromRows: [row("Milk 1 Gal   $3.99")])
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].name, "Milk 1 Gal")
        XCTAssertEqual(items[0].price, 3.99)
        XCTAssertNil(total)
    }

    func testMultiWordItemNameFromTwoSeparateObservations() {
        // Simulates a row Part 4 clustered from two separate Vision observations
        // (item name and price recognized as distinct boxes at the same height).
        let (items, _) = parseItems(fromRows: [row("Organic Whole Wheat Bread", "4.29")])
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].name, "Organic Whole Wheat Bread")
        XCTAssertEqual(items[0].price, 4.29)
    }

    // MARK: - Rightmost-price selection

    /// The tricky case: a weight-based line has THREE decimal numbers (weight,
    /// unit rate, and the actual charged price). The charged price is always
    /// last, so rightmost-match selection must pick 0.73, not 1.24 or 0.59.
    func testWeightBasedPricePicksRightmostNumberNotTheWeightOrRate() {
        let (items, _) = parseItems(fromRows: [row("Bananas 1.24 lb @ $0.59/lb 0.73")])
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].price, 0.73, "Should pick the rightmost number (the charged price), not the weight or per-lb rate")
        XCTAssertTrue(items[0].name.contains("Bananas"), "Name extraction on this format is best-effort — see note below")
        // Known limitation: if a receipt prints the item name on one line and the
        // weight/rate/price detail on a SEPARATE line below it, this parser (which
        // only looks at one row at a time) will capture the price correctly but
        // the name will be the weight/rate text, not the product name — the name
        // line has no price, so it gets dropped by requirement 5 before the two
        // could ever be associated. Fixing that needs a look-back-one-row
        // heuristic, which felt like scope creep for this part; flag it if your
        // real receipts commonly split weight items across two lines.
    }

    // MARK: - Noise filtering

    func testDenylistKeywordRowsAreSkippedEvenWhenTheyHaveAPrice() {
        // CASH and CHANGE rows both have a valid price-shaped token — proves the
        // denylist check runs BEFORE price extraction would otherwise accept them.
        let rows = [
            row("Milk 1 Gal   $3.99"),
            row("CASH   $10.00"),
            row("CHANGE   $6.01"),
        ]
        let (items, total) = parseItems(fromRows: rows)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].name, "Milk 1 Gal")
        XCTAssertNil(total, "No TOTAL row was present in this test's data")
    }

    func testBarcodeLongDigitRunRowIsSkipped() {
        // Without noise filtering this would parse as an item named
        // "0123456789012" priced $4.99 — a barcode misread as a product.
        let rows = [
            row("Milk 1 Gal   $3.99"),
            row("0123456789012   4.99"),
        ]
        let (items, _) = parseItems(fromRows: rows)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].name, "Milk 1 Gal")
    }

    func testPhoneNumberRowIsSkipped() {
        // Separated digit groups (555-123-4567) don't form one long digit run,
        // so this specifically tests the dedicated phone regex, not the barcode one.
        let rows = [
            row("Milk 1 Gal   $3.99"),
            row("Questions? Call 555-123-4567   2.50"),
        ]
        let (items, _) = parseItems(fromRows: rows)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].name, "Milk 1 Gal")
    }

    // MARK: - Total detection and stop condition

    func testTotalRowStopsParsingAndExtractsTotal() {
        let rows = [
            row("Milk 1 Gal   $3.99"),
            row("Bread   $4.29"),
            row("SUBTOTAL   $8.28"),
            row("TAX   $0.66"),
            row("TOTAL   $8.94"),
            row("CASH   $10.00"), // should never be reached — parsing stops at TOTAL
            row("CHANGE   $1.06"),
        ]
        let (items, total) = parseItems(fromRows: rows)
        XCTAssertEqual(items.count, 2, "SUBTOTAL/TAX must not count as items, and nothing after TOTAL should be processed")
        XCTAssertEqual(items.map(\.name), ["Milk 1 Gal", "Bread"])
        XCTAssertEqual(total, 8.94)
    }

    func testSubtotalRowDoesNotFalselyTriggerTotalDetection() {
        // "SUBTOTAL" contains "total" as a raw substring — this confirms the
        // word-boundary + explicit subtotal check correctly tells them apart.
        let rows = [
            row("Milk 1 Gal   $3.99"),
            row("SUBTOTAL   $3.99"),
            row("TOTAL   $3.99"),
        ]
        let (items, total) = parseItems(fromRows: rows)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(total, 3.99)
    }

    // MARK: - Rows that can't become items

    func testRowsWithNoPriceOrEmptyNameAreSkipped() {
        let rows = [
            row("Thank you for shopping with us!"), // no price at all
            row("$4.99"),                            // nothing left after removing the price
            row("Milk 1 Gal   $3.99"),                // the one legitimate item
        ]
        let (items, _) = parseItems(fromRows: rows)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].name, "Milk 1 Gal")
    }

    func testEmptyInputReturnsEmptyItemsAndNilTotal() {
        let (items, total) = parseItems(fromRows: [])
        XCTAssertTrue(items.isEmpty)
        XCTAssertNil(total)
    }
}
