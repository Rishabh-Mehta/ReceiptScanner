//
//  ManualReceiptSpotCheck.swift
//
//  Not a real pass/fail test — a way to see how the parser handles REAL receipt
//  text, using the same CI pipeline that's already working, with zero hardware.
//
//  How to use:
//  1. Grab a real receipt. Type out each printed line as its own string in the
//     `lines` array below, in top-to-bottom order, as close to verbatim as you
//     can manage (keep weird spacing/casing — that's the point).
//  2. Push. Open the Actions log for this test and read the printed output.
//  3. Compare what got printed to what the receipt actually says. Anything
//     wrong — a missed item, a bad price, a wrong category — is real signal:
//     bring that specific line back to a fresh chat with Part 5's or Part 7's
//     original prompt and ask for it to be handled.
//
//  This always "passes" (the assertion is trivially true) — its only purpose
//  is getting real data through the pipeline and into a log you can read.
//

import XCTest
@testable import ReceiptScannerKit

final class ManualReceiptSpotCheck: XCTestCase {

    func testRealReceiptSample() {
        // ↓↓↓ Replace this with lines typed from an actual receipt ↓↓↓
        let lines = [
            "TRADER JOE'S #123",
            "456 Main Street",
            "Anytown, ST 12345",
            "",
            "ORG BANANAS EA         0.29",
            "TRDR JOES BREAD          3.49",
            "MILK 1 GAL WHOLE         4.29",
            "CHKN BRST BNLS 1.24 lb @ 5.99/lb  7.43",
            "",
            "SUBTOTAL                15.50",
            "TAX                       1.24",
            "TOTAL                    16.74",
            "",
            "08/15/2026  2:14 PM",
        ]
        // ↑↑↑ Replace this with lines typed from an actual receipt ↑↑↑

        let ocrLines = lines.map { OCRLine(text: $0, boundingBox: .zero, confidence: 1.0) }

        // Each typed line = one already-clustered row (skipping clusterRows,
        // since there's no real Vision geometry for hand-typed text — this
        // matches how the existing unit tests treat single-line rows too).
        let rows = ocrLines.filter { !$0.text.isEmpty }.map { [$0] }

        let (items, total) = parseItems(fromRows: rows)
        let store = extractStoreName(from: ocrLines)
        let date = extractDate(from: ocrLines)
        let classifier = KeywordCategoryClassifier()

        print("\n========== PARSED RECEIPT ==========")
        print("Store: \(store ?? "nil")")
        print("Date:  \(date.map(String.init(describing:)) ?? "nil")")
        print("Items (\(items.count)):")
        for item in items {
            let category = classifier.categorize(itemName: item.name, storeName: store)
            print("  • \(item.name)  —  $\(item.price)  —  \(category.displayName)")
        }
        print("Total: \(total.map { "$\($0)" } ?? "nil (no TOTAL row recognized)")")
        print("=====================================\n")

        // Trivially true — this test exists to print, not to assert.
        XCTAssertTrue(true)
    }
}
