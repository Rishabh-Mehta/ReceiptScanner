//
//  CategoryClassifierTests.swift
//
//  Part 7 of the native receipt scanner build plan — unit tests for
//  KeywordCategoryClassifier. Add this file to your test target.
//

import XCTest
@testable import ReceiptScannerKit

final class CategoryClassifierTests: XCTestCase {

    private let classifier = KeywordCategoryClassifier()

    func testItemKeywordOverrideWinsEvenOnAGroceryReceipt() {
        // "Trader Joe's" alone would map to .groceries via the merchant tier —
        // the item-level "sandwich"/"combo" match must take priority over that.
        let category = classifier.categorize(itemName: "Turkey Sandwich Combo", storeName: "Trader Joe's #123")
        XCTAssertEqual(category, .dining)
    }

    func testFallsBackToMerchantDefaultWhenNoItemKeywordMatches() {
        let category = classifier.categorize(itemName: "Organic Bananas", storeName: "Whole Foods Market #55")
        XCTAssertEqual(category, .groceries)
    }

    func testFallsBackToOtherWhenNothingMatches() {
        let category = classifier.categorize(itemName: "Miscellaneous Item", storeName: "Joe's Corner Store")
        XCTAssertEqual(category, .other)
    }

    func testFallsBackToOtherSafelyWhenStoreNameIsNil() {
        // No item keyword match, and no store name to fall back to at all —
        // should resolve to .other without crashing.
        let category = classifier.categorize(itemName: "Miscellaneous Item", storeName: nil)
        XCTAssertEqual(category, .other)
    }

    func testMatchingIsCaseInsensitiveForBothTiers() {
        let itemTier = classifier.categorize(itemName: "DOUBLE BURGER MEAL", storeName: nil)
        XCTAssertEqual(itemTier, .dining)

        let merchantTier = classifier.categorize(itemName: "Random Item", storeName: "TRADER JOE'S #455")
        XCTAssertEqual(merchantTier, .groceries)
    }
}
