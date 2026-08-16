//
//  ReceiptScanTestView.swift
//
//  Part 9 of the native receipt scanner build plan — throwaway UI to verify the
//  whole pipeline (capture → OCR → clustering → parsing → categorization) works
//  end to end on real photos, before deciding how this fits into a bigger app.
//

import SwiftUI
import UIKit

public struct ReceiptScanTestView: View {
    @State private var isShowingScanner = false
    @State private var isProcessing = false
    @State private var parsedReceipt: ParsedReceipt?
    @State private var errorMessage: String?

    private let scanner = ReceiptScanner(classifier: KeywordCategoryClassifier())

    // Explicit public init is required — Swift never auto-generates a public
    // initializer even for a public type, only internal ones. Without this,
    // external code could see the type but never actually construct it.
    public init() {}

    public var body: some View {
        NavigationStack {
            content
                .navigationTitle("Receipt Scan Test")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            isShowingScanner = true
                        } label: {
                            Label("Scan Receipt", systemImage: "camera.viewfinder")
                        }
                    }
                }
                .fullScreenCover(isPresented: $isShowingScanner) {
                    DocumentScannerView { image in
                        Task { await process(image) }
                    }
                    .ignoresSafeArea()
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if isProcessing {
            ProgressView("Reading receipt…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundStyle(.orange)
                Text(errorMessage)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Button("Try Again") { isShowingScanner = true }
                    .buttonStyle(.borderedProminent)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let parsedReceipt {
            receiptList(for: parsedReceipt)
        } else {
            ContentUnavailableView(
                "No Receipt Yet",
                systemImage: "doc.text.viewfinder",
                description: Text("Tap Scan Receipt to test the pipeline on a real photo.")
            )
        }
    }

    private func receiptList(for receipt: ParsedReceipt) -> some View {
        List {
            Section("Store") {
                Text(receipt.store)
                Text(receipt.date, style: .date)
                    .foregroundStyle(.secondary)
            }
            Section("Items (\(receipt.items.count))") {
                if receipt.items.isEmpty {
                    Text("No line items were recognized.")
                        .foregroundStyle(.secondary)
                }
                ForEach(receipt.items) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name)
                            Text(item.category.displayName)
                                .font(.caption)
                                .foregroundStyle(Color(hex: item.category.colorHex))
                        }
                        Spacer()
                        Text(item.price, format: .currency(code: "USD"))
                            .monospacedDigit()
                    }
                }
            }
            Section {
                HStack {
                    Text("Total").fontWeight(.semibold)
                    Spacer()
                    Text(receipt.total, format: .currency(code: "USD"))
                        .fontWeight(.semibold)
                        .monospacedDigit()
                }
            }
        }
    }

    private func process(_ image: UIImage) async {
        errorMessage = nil
        parsedReceipt = nil
        isProcessing = true
        defer { isProcessing = false }

        do {
            parsedReceipt = try await scanner.scan(image: image)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// Turns a category's stored hex string (no leading "#", e.g. "4CAF50") into a
/// SwiftUI Color, just for tinting the category label in this test screen.
private extension Color {
    init(hex: String) {
        let sanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        Scanner(string: sanitized).scanHexInt64(&rgb)
        self.init(
            red: Double((rgb & 0xFF0000) >> 16) / 255,
            green: Double((rgb & 0x00FF00) >> 8) / 255,
            blue: Double(rgb & 0x0000FF) / 255
        )
    }
}

#Preview {
    ReceiptScanTestView()
}
