//
//  CategoryClassifier.swift
//
//  Part 7 of the native receipt scanner build plan — categorization only.
//  Fully offline: no network call, no LLM. Keyword/dictionary-based lookup only.
//

import Foundation

/// Assigns a ReceiptCategory to a line item. Defined as a protocol specifically so
/// KeywordCategoryClassifier can later be swapped for a Core ML–based classifier
/// (once you have enough real-world categorization data to train one) without
/// touching anything that calls `categorize(itemName:storeName:)` — e.g. Part 8's
/// ReceiptScanner holds a `let classifier: CategoryClassifying`, not a concrete type.
///
/// A future drop-in replacement would look like:
///
///     struct CoreMLCategoryClassifier: CategoryClassifying {
///         let model: YourTrainedModel
///         func categorize(itemName: String, storeName: String?) -> ReceiptCategory {
///             // run itemName (and maybe storeName) through `model`, map its
///             // output label back to a ReceiptCategory case.
///         }
///     }
///
/// — same call site, same signature, zero changes anywhere else.
protocol CategoryClassifying {
    func categorize(itemName: String, storeName: String?) -> ReceiptCategory
}

/// Offline categorization using two ordered keyword tiers. Item-level keywords are
/// checked first since they're more specific than a merchant default (a burger on
/// a grocery receipt should still be Dining, not Groceries).
///
/// Both keyword lists are deliberately **ordered arrays, not dictionaries** — a
/// plain `[String: ReceiptCategory]` doesn't guarantee iteration order in Swift,
/// which would make categorization non-deterministic if an item ever happened to
/// contain two keywords mapping to different categories (e.g. an item name that
/// coincidentally contains both "salad" and some other matched word). An ordered
/// array means the same input always produces the same output, and priority
/// between overlapping keywords is explicit rather than accidental.
struct KeywordCategoryClassifier: CategoryClassifying {

    func categorize(itemName: String, storeName: String?) -> ReceiptCategory {
        let lowerItem = itemName.lowercased()

        // Tier 1: item-level override — checked first, wins if it matches.
        for entry in Self.itemKeywords where lowerItem.contains(entry.keyword) {
            return entry.category
        }

        // Tier 2: merchant-level default.
        if let storeName {
            let lowerStore = storeName.lowercased()
            for entry in Self.merchantKeywords where lowerStore.contains(entry.keyword) {
                return entry.category
            }
        }

        return .other
    }

    // MARK: - Keyword tables (starter lists — extend freely as you see real data)

    private static let itemKeywords: [(keyword: String, category: ReceiptCategory)] = [
        // Dining — the case explicitly called out: these should win even on a
        // grocery or convenience-store receipt.
        ("burger", .dining),
        ("sandwich", .dining),
        ("combo", .dining),
        ("pizza", .dining),
        ("burrito", .dining),
        ("taco", .dining),
        ("salad", .dining),
        // Health — common pharmacy-aisle items that might appear on a grocery
        // store's combined receipt rather than a dedicated pharmacy receipt.
        ("vitamin", .health),
        ("ibuprofen", .health),
        ("bandage", .health),
        // Transport — fuel line items at a grocery store or convenience store.
        ("gasoline", .transport),
        ("fuel", .transport),
        // Entertainment
        ("movie ticket", .entertainment),
    ]

    private static let merchantKeywords: [(keyword: String, category: ReceiptCategory)] = [
        // Groceries
        ("trader joe", .groceries),
        ("whole foods", .groceries),
        ("safeway", .groceries),
        ("kroger", .groceries),
        // Dining
        ("starbucks", .dining),
        ("mcdonald", .dining),
        ("chipotle", .dining),
        // Transport
        ("shell", .transport),
        ("chevron", .transport),
        ("uber", .transport),
        ("lyft", .transport),
        // Shopping
        ("amazon", .shopping),
        ("target", .shopping),
        ("walmart", .shopping),
        // Health
        ("cvs", .health),
        ("walgreens", .health),
        ("rite aid", .health),
        // Entertainment
        ("netflix", .entertainment),
        ("spotify", .entertainment),
        // Utilities
        ("comcast", .utilities),
        ("verizon", .utilities),
        ("pg&e", .utilities),
    ]
}
