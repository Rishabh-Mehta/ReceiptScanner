//
//  DocumentScannerView.swift
//
//  Part 2 of the native receipt scanner build plan — capture screen only.
//  Wraps VNDocumentCameraViewController (VisionKit) for use in SwiftUI.
//
//  NOTE: VNDocumentCameraViewController requires a physical device — the iOS
//  Simulator has no camera, so this cannot be tested in Simulator. Run on a
//  real iPhone to verify.
//

import SwiftUI
import UIKit
import VisionKit

/// Presents Apple's built-in document scanner (auto edge detection + perspective
/// correction) and hands back the first scanned page as a UIImage.
///
/// Present this as a `.sheet` or `.fullScreenCover` — it dismisses itself via the
/// SwiftUI environment on completion, cancel, or failure.
struct DocumentScannerView: UIViewControllerRepresentable {
    /// Fires with the first scanned page once the person finishes scanning.
    /// Multi-page scans are ignored for now — only page 0 is used.
    var onScan: (UIImage) -> Void

    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {
        // Nothing to update — VNDocumentCameraViewController manages its own state.
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan, dismiss: dismiss)
    }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        private let onScan: (UIImage) -> Void
        private let dismiss: DismissAction

        init(onScan: @escaping (UIImage) -> Void, dismiss: DismissAction) {
            self.onScan = onScan
            self.dismiss = dismiss
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFinishWith scan: VNDocumentCameraScan
        ) {
            defer { dismiss() }
            guard scan.pageCount > 0 else { return }
            onScan(scan.imageOfPage(at: 0))
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            // Person tapped Cancel — just close, no error state needed.
            dismiss()
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFailWithError error: Error
        ) {
            // Log and close rather than crash or surface a raw error to the person.
            print("DocumentScannerView: scan failed — \(error.localizedDescription)")
            dismiss()
        }
    }
}
