//
//  ReceiptItemParser.swift
//
//  Part 5 of the native receipt scanner build plan — line-item parsing.
//  This is the part most worth iterating on against real receipts.
//

import Foundation

// MARK: - Configuration

/// Rows containing any of these words (case-insensitive, whole-word match) are
/// treated as receipt noise, not items — with "total" handled separately below
/// since it's also the terminal signal that ends item parsing.
private let noiseKeywords = [
    "SUBTOTAL", "TAX", "TOTAL", "CASH", "CHANGE", "CARD", "VISA", "MASTERCARD",
    "DEBIT", "CREDIT", "BALANCE", "TENDER", "AUTH", "APPROVED",
]

// Compiled once, not per-row — this file runs against every row of every scan.
private let noiseKeywordRegexes: [NSRegularExpression] = noiseKeywords.compactMap { wordRegex($0) }
private let totalWordRegex = wordRegex("total")
private let subtotalWordRegex = wordRegex("subtotal")

/// Matches a dollar amount: optional "$", 1–5 digits, a literal decimal point,
/// exactly 2 digits, and NOT followed by another digit (the trailing lookahead
/// stops "12.005" from matching as if it were "12.00" — receipts always have
/// exactly 2 decimal places on real prices, never 3).
private let priceRegex = try! NSRegularExpression(pattern: #"\$?\d{1,5}\.\d{2}(?!\d)"#)

/// Common US phone formats with digit-group separators: (555) 123-4567,
/// 555-123-4567, 555.123.4567. A bare 10-digit run with no separators is instead
/// caught by `longDigitRunRegex` below.
private let phoneRegex = try! NSRegularExpression(pattern: #"\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}"#)

/// 8+ consecutive digits with no decimal point — barcodes, SKUs, and transaction
/// IDs look like this; real prices never do (the decimal point always breaks up
/// the digit run at 1–5 digits).
private let longDigitRunRegex = try! NSRegularExpression(pattern: #"\d{8,}"#)

private func wordRegex(_ word: String) -> NSRegularExpression {
    // swiftlint:disable:next force_try — pattern is built from a fixed literal, always valid.
    try! NSRegularExpression(
        pattern: "\\b\(NSRegularExpression.escapedPattern(for: word))\\b",
        options: .caseInsensitive
    )
}

// MARK: - Public API

/// Turns clustered, top-to-bottom-sorted rows into line items plus the receipt
/// total, using regex-based price detection and keyword-based noise filtering.
/// No OCR or clustering happens here — rows are assumed to already be in reading
/// order (Parts 3–4).
func parseItems(fromRows rows: [[OCRLine]]) -> (items: [ReceiptItem], total: Double?) {
    var items: [ReceiptItem] = []
    var total: Double?

    for row in rows {
        let rowText = collapseWhitespace(row.map(\.text).joined(separator: " "))
        guard !rowText.isEmpty else { continue }

        // Terminal condition: the real TOTAL line ends item parsing entirely.
        // The whole-word regex for "total" already won't match inside "SUBTOTAL"
        // on its own (there's no word boundary between the "B" and the "T" — both
        // are letters, so \b doesn't fire there). The explicit subtotal check is
        // a defensive second guard, e.g. for a summary row that mentions both
        // words together ("SUBTOTAL / TOTAL breakdown").
        if matches(totalWordRegex, rowText) && !matches(subtotalWordRegex, rowText) {
            total = rightmostPriceMatch(in: rowText)?.value
            break
        }

        if isNoiseRow(rowText) {
            continue
        }

        guard let priceMatch = rightmostPriceMatch(in: rowText) else {
            continue // No price found on this row — can't treat it as an item.
        }

        var name = rowText
        name.removeSubrange(priceMatch.range)
        name = collapseWhitespace(name)

        guard !name.isEmpty else { continue }

        items.append(ReceiptItem(name: name, price: priceMatch.value, category: .other))
    }

    return (items, total)
}

// MARK: - Helpers

private func isNoiseRow(_ text: String) -> Bool {
    if noiseKeywordRegexes.contains(where: { matches($0, text) }) { return true }
    if matches(phoneRegex, text) { return true }
    if matches(longDigitRunRegex, text) { return true }
    return false
}

private func matches(_ regex: NSRegularExpression, _ text: String) -> Bool {
    let range = NSRange(text.startIndex..., in: text)
    return regex.firstMatch(in: text, range: range) != nil
}

/// Finds every dollar-amount-shaped match in `text` and returns the rightmost one
/// — on a receipt row, the price is almost always the last number on the line
/// (item name/weight/unit-rate details, if any, come before it).
private func rightmostPriceMatch(in text: String) -> (value: Double, range: Range<String.Index>)? {
    let nsRange = NSRange(text.startIndex..., in: text)
    guard
        let lastMatch = priceRegex.matches(in: text, range: nsRange).last,
        let range = Range(lastMatch.range, in: text)
    else { return nil }

    let numericString = text[range].replacingOccurrences(of: "$", with: "")
    guard let value = Double(numericString) else { return nil }
    return (value, range)
}

private func collapseWhitespace(_ text: String) -> String {
    text.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
}
