//
//  ReceiptScanner.swift
//
//  Part 8 of the native receipt scanner build plan — orchestrator only.
//  Composes the existing pieces from Parts 3–7; no new parsing logic here.
//

import Foundation
import UIKit

enum ReceiptScannerError: LocalizedError {
    case noTextRecognized

    var errorDescription: String? {
        switch self {
        case .noTextRecognized:
            return "Couldn't find any text on that receipt. Try a clearer, flatter photo."
        }
    }
}

struct ReceiptScanner {
    let classifier: CategoryClassifying

    func scan(image: UIImage) async throws -> ParsedReceipt {
        // OCR (Part 3). recognizeText throws for a genuinely invalid image, but
        // returns [] (not an error) when the image is fine but no text was
        // found — that empty case becomes a real error here, since a scan with
        // zero recognized text isn't a usable result for anything downstream.
        let lines = try await recognizeText(in: image)
        guard !lines.isEmpty else {
            throw ReceiptScannerError.noTextRecognized
        }

        // Row clustering (Part 4) + item/total parsing (Part 5).
        let rows = clusterRows(lines)
        let (rawItems, extractedTotal) = parseItems(fromRows: rows)

        // Metadata (Part 6) — extracted from the full, un-clustered line list.
        let extractedStoreName = extractStoreName(from: lines)
        let date = extractDate(from: lines) ?? Date()

        // Categorization (Part 7). Deliberately passes the RAW optional store
        // name (nil if extraction failed), not a display fallback string —
        // KeywordCategoryClassifier already handles nil safely, and passing it
        // a fake placeholder like "Unknown store" would just be dead weight
        // that can never match a real merchant keyword anyway.
        let categorizedItems = rawItems.map { item in
            ReceiptItem(
                id: item.id,
                name: item.name,
                price: item.price,
                category: classifier.categorize(itemName: item.name, storeName: extractedStoreName)
            )
        }

        // The display-friendly fallback is applied here, only for the field
        // that's actually shown to a person.
        let store = extractedStoreName ?? "Unknown store"

        // If no TOTAL row was recognized, fall back to summing the parsed items
        // rather than leaving the receipt with an undefined total.
        let total = extractedTotal ?? categorizedItems.reduce(0) { $0 + $1.price }

        return ParsedReceipt(store: store, date: date, items: categorizedItems, total: total)
    }
}
