//
//  ReceiptOCR.swift
//
//  Part 3 of the native receipt scanner build plan — OCR extraction only.
//  Runs entirely on-device via the Vision framework, no network call.
//

import Foundation
import UIKit
import Vision

enum ReceiptOCRError: LocalizedError {
    case invalidImage

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Couldn't read the image data for OCR."
        }
    }
}

/// Runs on-device text recognition on `image` and returns each recognized piece of
/// text with its position and confidence. Returns an empty array (not an error) if
/// no text is found — that's a normal outcome, not a failure.
func recognizeText(in image: UIImage) async throws -> [OCRLine] {
    guard let cgImage = image.cgImage else {
        throw ReceiptOCRError.invalidImage
    }
    // UIImage can carry an orientation flag separate from the underlying CGImage's
    // raw pixel layout (common with photos taken in portrait). Vision needs the
    // real orientation to report correct bounding boxes — get this wrong and every
    // later part (row clustering, store-name-near-top heuristics) breaks.
    let orientation = cgOrientation(from: image.imageOrientation)

    return try await withCheckedThrowingContinuation { continuation in
        // Vision's handler.perform(_:) is synchronous and can take real time on
        // .accurate mode, so it's dispatched to a background queue rather than
        // run directly on a Swift concurrency thread-pool thread.
        DispatchQueue.global(qos: .userInitiated).async {
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }
                let lines: [OCRLine] = observations.compactMap { observation in
                    guard let candidate = observation.topCandidates(1).first else { return nil }
                    return OCRLine(
                        text: candidate.string,
                        boundingBox: observation.boundingBox,
                        confidence: candidate.confidence
                    )
                }
                continuation.resume(returning: lines)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

/// Maps UIImage's orientation enum to the CGImagePropertyOrientation Vision expects.
private func cgOrientation(from uiOrientation: UIImage.Orientation) -> CGImagePropertyOrientation {
    switch uiOrientation {
    case .up: return .up
    case .upMirrored: return .upMirrored
    case .down: return .down
    case .downMirrored: return .downMirrored
    case .left: return .left
    case .leftMirrored: return .leftMirrored
    case .right: return .right
    case .rightMirrored: return .rightMirrored
    @unknown default: return .up
    }
}
