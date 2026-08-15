//
//  RowClusterer.swift
//
//  Part 4 of the native receipt scanner build plan — row clustering only.
//  Groups raw OCRLine observations into logical printed rows.
//

import CoreGraphics

/// Groups OCR observations that sit on the same printed line into rows.
///
/// Vision sometimes splits one visual line into multiple observations (e.g. an
/// item name and its price recognized as two separate boxes at the same height),
/// so this clusters by vertical (Y-axis) overlap rather than assuming one
/// observation == one row.
///
/// Algorithm: sort all lines top-to-bottom, then walk through them in order,
/// comparing each line's vertical overlap against a *reference box* — the first
/// line added to the row currently being built. If the overlap ratio (intersection
/// height ÷ the shorter of the two boxes' heights) meets `yOverlapThreshold`, the
/// line joins that row; otherwise it starts a new row and becomes the new
/// reference. Using a fixed reference per row (rather than growing the row's
/// bounds as lines are added) avoids the row's vertical band slowly drifting down
/// the receipt and swallowing the next real row.
///
/// - Parameters:
///   - lines: raw OCR observations, in any order.
///   - yOverlapThreshold: minimum vertical overlap ratio (0...1) for two lines to
///     be considered the same row. Default 0.5 works well for typical receipt
///     fonts; receipts with unusually tight or loose line spacing may need this
///     tuned — raise it to split more aggressively, lower it to merge more.
/// - Returns: rows sorted top-to-bottom; each row's lines sorted left-to-right.
func clusterRows(_ lines: [OCRLine], yOverlapThreshold: CGFloat = 0.5) -> [[OCRLine]] {
    guard !lines.isEmpty else { return [] }

    // Vision's Y origin is bottom-left, so higher midY = higher up on the receipt.
    let sorted = lines.sorted { $0.boundingBox.midY > $1.boundingBox.midY }

    var rows: [[OCRLine]] = []
    var currentRow: [OCRLine] = [sorted[0]]
    var rowReferenceBox = sorted[0].boundingBox

    for line in sorted.dropFirst() {
        if verticalOverlapRatio(line.boundingBox, rowReferenceBox) >= yOverlapThreshold {
            currentRow.append(line)
        } else {
            rows.append(currentRow)
            currentRow = [line]
            rowReferenceBox = line.boundingBox
        }
    }
    rows.append(currentRow)

    return rows
        .map { row in row.sorted { $0.boundingBox.minX < $1.boundingBox.minX } }
        .sorted { averageMidY($0) > averageMidY($1) }
}

/// Fraction of the shorter box's height that the two boxes overlap on the Y-axis.
/// 1.0 = fully overlapping (same height range), 0.0 = no overlap at all.
private func verticalOverlapRatio(_ a: CGRect, _ b: CGRect) -> CGFloat {
    let intersectionTop = min(a.maxY, b.maxY)
    let intersectionBottom = max(a.minY, b.minY)
    let intersectionHeight = max(0, intersectionTop - intersectionBottom)
    let shorterHeight = min(a.height, b.height)
    guard shorterHeight > 0 else { return 0 }
    return intersectionHeight / shorterHeight
}

private func averageMidY(_ row: [OCRLine]) -> CGFloat {
    guard !row.isEmpty else { return 0 }
    return row.reduce(0) { $0 + $1.boundingBox.midY } / CGFloat(row.count)
}
