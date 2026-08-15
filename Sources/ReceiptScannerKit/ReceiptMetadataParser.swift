//
//  ReceiptMetadataParser.swift
//
//  Part 6 of the native receipt scanner build plan — store name + date only.
//  Input is the full, un-clustered [OCRLine] array (before row clustering).
//

import Foundation
import CoreGraphics

// MARK: - Store name

/// Picks the store name from the top 20% of the receipt (by boundingBox.minY —
/// Vision's Y origin is bottom-left, so "top of receipt" means high Y), preferring
/// the tallest bounding box there as a proxy for the largest font size. If several
/// lines in that band tie for tallest, the physically topmost of them wins.
func extractStoreName(from lines: [OCRLine]) -> String? {
    guard !lines.isEmpty else { return nil }

    let minYValues = lines.map(\.boundingBox.minY)
    guard let highestMinY = minYValues.max(), let lowestMinY = minYValues.min() else { return nil }

    let verticalRange = highestMinY - lowestMinY
    let topBandThreshold = highestMinY - 0.2 * verticalRange

    // Sorted topmost-first BEFORE the height comparison below, so that when
    // max(by:) hits a height tie (Swift keeps the first element it saw, not the
    // last), the one it keeps is genuinely the topmost of the tied lines — not
    // just whichever happened to come first in Vision's raw output order.
    let topBandLines = lines
        .filter { $0.boundingBox.minY >= topBandThreshold }
        .sorted { $0.boundingBox.minY > $1.boundingBox.minY }

    guard let storeLine = topBandLines.max(by: { $0.boundingBox.height < $1.boundingBox.height }) else {
        return nil
    }

    let trimmed = storeLine.text.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
}

// MARK: - Date

/// Scans every line, in the order given, for the first recognizable date. Returns
/// nil rather than guessing if nothing matches any known format.
func extractDate(from lines: [OCRLine]) -> Date? {
    for line in lines {
        if let date = firstDate(in: line.text) {
            return date
        }
    }
    return nil
}

private struct DatePattern {
    let regex: NSRegularExpression
    let parse: (NSTextCheckingResult, String) -> Date?
}

private func firstDate(in text: String) -> Date? {
    let nsRange = NSRange(text.startIndex..., in: text)
    for pattern in datePatterns {
        if let match = pattern.regex.firstMatch(in: text, range: nsRange),
           let date = pattern.parse(match, text) {
            return date
        }
    }
    return nil
}

// Trailing `(?!\d)` guards prevent one pattern from partially matching inside a
// longer number that actually belongs to a different pattern (the same lesson
// from the price regex in Part 5 — e.g. without it, "MM/DD/YY" could match just
// the first 2 digits of a 4-digit year in an "MM/DD/YYYY" date).
private let isoRegex = try! NSRegularExpression(pattern: #"\b(\d{4})-(\d{1,2})-(\d{1,2})(?!\d)"#)
private let slashLongYearRegex = try! NSRegularExpression(pattern: #"\b(\d{1,2})/(\d{1,2})/(\d{4})(?!\d)"#)
private let dashLongYearRegex = try! NSRegularExpression(pattern: #"\b(\d{1,2})-(\d{1,2})-(\d{4})(?!\d)"#)
private let slashShortYearRegex = try! NSRegularExpression(pattern: #"\b(\d{1,2})/(\d{1,2})/(\d{2})(?!\d)"#)
private let monthNameRegex = try! NSRegularExpression(
    pattern: #"\b(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-zA-Z]*\.?\s+(\d{1,2}),?\s+(\d{4})\b"#,
    options: .caseInsensitive
)

// Longer/more specific patterns first — mostly doesn't matter given the
// lookahead guards above, but keeps intent obvious.
private let datePatterns: [DatePattern] = [
    DatePattern(regex: isoRegex, parse: parseISO),
    DatePattern(regex: slashLongYearRegex, parse: parseSlashLongYear),
    DatePattern(regex: dashLongYearRegex, parse: parseDashLongYear),
    DatePattern(regex: slashShortYearRegex, parse: parseSlashShortYear),
    DatePattern(regex: monthNameRegex, parse: parseMonthName),
]

private let monthAbbreviations: [String: Int] = [
    "jan": 1, "feb": 2, "mar": 3, "apr": 4, "may": 5, "jun": 6,
    "jul": 7, "aug": 8, "sep": 9, "oct": 10, "nov": 11, "dec": 12,
]

private func parseISO(_ match: NSTextCheckingResult, _ text: String) -> Date? {
    guard
        let year = intGroup(1, in: match, text: text),
        let month = intGroup(2, in: match, text: text),
        let day = intGroup(3, in: match, text: text)
    else { return nil }
    return makeDate(year: year, month: month, day: day)
}

private func parseSlashLongYear(_ match: NSTextCheckingResult, _ text: String) -> Date? {
    guard
        let month = intGroup(1, in: match, text: text),
        let day = intGroup(2, in: match, text: text),
        let year = intGroup(3, in: match, text: text)
    else { return nil }
    return makeDate(year: year, month: month, day: day)
}

private func parseDashLongYear(_ match: NSTextCheckingResult, _ text: String) -> Date? {
    parseSlashLongYear(match, text) // same group order (month, day, year), different separator
}

private func parseSlashShortYear(_ match: NSTextCheckingResult, _ text: String) -> Date? {
    guard
        let month = intGroup(1, in: match, text: text),
        let day = intGroup(2, in: match, text: text),
        let shortYear = intGroup(3, in: match, text: text)
    else { return nil }
    // Standard pivot-year heuristic: 00–69 → 2000s, 70–99 → 1900s. Receipts are
    // realistically always the former, but the pivot is included for correctness.
    let fullYear = shortYear < 70 ? 2000 + shortYear : 1900 + shortYear
    return makeDate(year: fullYear, month: month, day: day)
}

private func parseMonthName(_ match: NSTextCheckingResult, _ text: String) -> Date? {
    guard
        let monthRange = Range(match.range(at: 1), in: text),
        let month = monthAbbreviations[text[monthRange].lowercased()],
        let day = intGroup(2, in: match, text: text),
        let year = intGroup(3, in: match, text: text)
    else { return nil }
    return makeDate(year: year, month: month, day: day)
}

private func intGroup(_ index: Int, in match: NSTextCheckingResult, text: String) -> Int? {
    guard let range = Range(match.range(at: index), in: text) else { return nil }
    return Int(text[range])
}

private func makeDate(year: Int, month: Int, day: Int) -> Date? {
    guard (1...12).contains(month), (1...31).contains(day) else { return nil }
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC") ?? .current // avoid local-timezone off-by-one-day bugs
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    return calendar.date(from: components)
}
