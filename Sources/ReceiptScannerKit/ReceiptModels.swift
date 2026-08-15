//
//  ReceiptModels.swift
//
//  Part 1 of the native receipt scanner build plan — shared data models only.
//  No persistence, no UI, no OCR/parsing logic yet (that's later parts).
//

import Foundation
import CoreGraphics

// MARK: - ReceiptCategory

/// The set of categories a receipt line item can be classified into.
enum ReceiptCategory: String, Codable, CaseIterable, Identifiable {
    case groceries
    case dining
    case transport
    case shopping
    case health
    case entertainment
    case utilities
    case other

    var id: String { rawValue }

    /// Human-readable label for display in UI.
    var displayName: String {
        switch self {
        case .groceries: return "Groceries"
        case .dining: return "Dining"
        case .transport: return "Transport"
        case .shopping: return "Shopping"
        case .health: return "Health"
        case .entertainment: return "Entertainment"
        case .utilities: return "Utilities"
        case .other: return "Other"
        }
    }

    /// Hex color (no leading "#") used to tint icons/badges for this category in UI.
    var colorHex: String {
        switch self {
        case .groceries: return "4CAF50"
        case .dining: return "FF7043"
        case .transport: return "42A5F5"
        case .shopping: return "FFC107"
        case .health: return "EC407A"
        case .entertainment: return "AB47BC"
        case .utilities: return "78909C"
        case .other: return "9E9E9E"
        }
    }
}

// MARK: - ReceiptItem

/// A single line item on a receipt — e.g. "Organic Bananas, $2.49, Groceries".
struct ReceiptItem: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var price: Double
    var category: ReceiptCategory

    init(id: UUID = UUID(), name: String, price: Double, category: ReceiptCategory) {
        self.id = id
        self.name = name
        self.price = price
        self.category = category
    }
}

// MARK: - ParsedReceipt

/// The fully parsed result of scanning a receipt: store, date, line items, and total.
struct ParsedReceipt: Codable, Equatable {
    var store: String
    var date: Date
    var items: [ReceiptItem]
    var total: Double
}

// MARK: - OCRLine

/// One piece of recognized text from Vision's OCR, with its position on the image.
///
/// `boundingBox` uses Vision's normalized coordinate space: origin (0, 0) is the
/// bottom-left corner of the image, (1, 1) is the top-right — regardless of the
/// image's actual pixel dimensions. This matters in later parts, e.g. when
/// clustering lines into rows or finding the store name near the top of the receipt
/// (which means the *highest* boundingBox.minY, since Y increases upward here).
struct OCRLine: Codable, Equatable {
    var text: String
    var boundingBox: CGRect
    var confidence: Float
}
