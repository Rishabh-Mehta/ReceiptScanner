//
//  ReceiptMetadataParserTests.swift
//
//  Part 6 of the native receipt scanner build plan — unit tests for
//  extractStoreName and extractDate. Add this file to your test target.
//

import XCTest
@testable import ReceiptScannerKit

final class ReceiptMetadataParserTests: XCTestCase {

    private func line(_ text: String, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat) -> OCRLine {
        OCRLine(text: text, boundingBox: CGRect(x: x, y: y, width: w, height: h), confidence: 0.9)
    }

    private struct YMD: Equatable {
        let year: Int
        let month: Int
        let day: Int
    }

    private func dateComponents(of date: Date) -> YMD {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return YMD(year: c.year!, month: c.month!, day: c.day!)
    }

    // MARK: - Store name

    func testStoreNameIsLargestTextInTopBand_IgnoringATallerFooterLine() {
        let lines = [
            line("SUPER MART", x: 0.10, y: 0.93, w: 0.50, h: 0.06),          // top band, tallest there
            line("123 Main Street", x: 0.15, y: 0.89, w: 0.40, h: 0.025),
            line("Anytown, ST 12345", x: 0.15, y: 0.86, w: 0.40, h: 0.022),
            line("Item 1   $2.99", x: 0.05, y: 0.50, w: 0.40, h: 0.020),
            // Deliberately the tallest box on the whole receipt, but it's a
            // footer line, not in the top 20% — must NOT be picked.
            line("THANK YOU FOR SHOPPING - VISIT AGAIN SOON!", x: 0.02, y: 0.02, w: 0.90, h: 0.08),
        ]
        XCTAssertEqual(extractStoreName(from: lines), "SUPER MART")
    }

    func testStoreNameHeightTieBreaksToTopmostLine_RegardlessOfInputOrder() {
        let storeA = line("STORE A", x: 0.05, y: 0.95, w: 0.30, h: 0.05)   // topmost, tied height
        let storeB = line("STORE B", x: 0.05, y: 0.90, w: 0.30, h: 0.05)   // tied height, lower
        let address = line("123 Main St", x: 0.05, y: 0.85, w: 0.30, h: 0.02)
        let item = line("Item 1   $2.99", x: 0.05, y: 0.50, w: 0.40, h: 0.02)
        let total = line("TOTAL   $2.99", x: 0.05, y: 0.10, w: 0.40, h: 0.02)

        // Shuffled on purpose — the result must not depend on array order.
        let shuffled = [total, address, storeB, item, storeA]
        XCTAssertEqual(extractStoreName(from: shuffled), "STORE A")
    }

    func testStoreNameReturnsNilForEmptyInput() {
        XCTAssertNil(extractStoreName(from: []))
    }

    // MARK: - Date

    func testExtractsSlashFormatWithFourDigitYear() {
        let lines = [line("Date: 08/15/2026", x: 0, y: 0, w: 0, h: 0)]
        guard let date = extractDate(from: lines) else {
            return XCTFail("Expected a date")
        }
        let c = dateComponents(of: date)
        XCTAssertEqual(c, YMD(year: 2026, month: 8, day: 15))
    }

    func testExtractsISOFormat() {
        let lines = [line("2026-08-15 14:32", x: 0, y: 0, w: 0, h: 0)]
        guard let date = extractDate(from: lines) else {
            return XCTFail("Expected a date")
        }
        let c = dateComponents(of: date)
        XCTAssertEqual(c, YMD(year: 2026, month: 8, day: 15))
    }

    func testExtractsMonthNameFormat() {
        let lines = [line("Receipt printed Jan 5, 2026", x: 0, y: 0, w: 0, h: 0)]
        guard let date = extractDate(from: lines) else {
            return XCTFail("Expected a date")
        }
        let c = dateComponents(of: date)
        XCTAssertEqual(c, YMD(year: 2026, month: 1, day: 5))
    }

    func testScansMultipleLinesInOrderAndReturnsFirstMatch() {
        let lines = [
            line("SUPER MART", x: 0, y: 0, w: 0, h: 0),
            line("123 Main Street", x: 0, y: 0, w: 0, h: 0),  // no date here
            line("08/15/2026  2:14 PM", x: 0, y: 0, w: 0, h: 0), // first line with a date
            line("Cashier: 04-02-2020", x: 0, y: 0, w: 0, h: 0), // a later, different date — ignored
        ]
        guard let date = extractDate(from: lines) else {
            return XCTFail("Expected a date")
        }
        let c = dateComponents(of: date)
        XCTAssertEqual(c, YMD(year: 2026, month: 8, day: 15), "Should return the first line with a match, not a later one")
    }

    /// Confirms "return nil rather than guessing" — none of these lines are
    /// dates, including a phone number and a bare digit run that could
    /// theoretically be misread as a date if the regexes were too loose.
    func testReturnsNilWhenNoDateIsPresent() {
        let lines = [
            line("SUPER MART", x: 0, y: 0, w: 0, h: 0),
            line("Call us: 555-123-4567", x: 0, y: 0, w: 0, h: 0),
            line("Trans# 0815202634", x: 0, y: 0, w: 0, h: 0), // 10-digit run, no separators — not a date shape
            line("TOTAL   $12.99", x: 0, y: 0, w: 0, h: 0),
        ]
        XCTAssertNil(extractDate(from: lines))
    }
}
