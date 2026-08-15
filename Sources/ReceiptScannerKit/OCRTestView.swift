//
//  OCRTestView.swift
//
//  Part 3 of the native receipt scanner build plan — throwaway test screen to
//  eyeball raw OCR output before parsing logic is built on top of it (Part 4+).
//
//  Works in Simulator (unlike the camera scanner) since it reads from the photo
//  library — just add a receipt photo to the Simulator's Photos app first
//  (drag an image file onto the Simulator window to add it).
//

import SwiftUI
import PhotosUI
import UIKit

struct OCRTestView: View {
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var ocrLines: [OCRLine] = []
    @State private var isProcessing = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    Label("Choose Receipt Photo", systemImage: "photo.on.rectangle")
                }
                .buttonStyle(.borderedProminent)

                if let selectedImage {
                    Image(uiImage: selectedImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 180)
                        .cornerRadius(8)
                }

                if isProcessing {
                    ProgressView("Recognizing text…")
                } else if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.footnote)
                } else if !ocrLines.isEmpty {
                    List(ocrLines.indices, id: \.self) { index in
                        let line = ocrLines[index]
                        VStack(alignment: .leading, spacing: 2) {
                            Text(line.text)
                                .font(.body)
                            Text(String(
                                format: "confidence %.2f · box (%.2f, %.2f, %.2f, %.2f)",
                                line.confidence,
                                line.boundingBox.origin.x, line.boundingBox.origin.y,
                                line.boundingBox.width, line.boundingBox.height
                            ))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        }
                    }
                    .listStyle(.plain)
                } else {
                    ContentUnavailableView(
                        "No Text Yet",
                        systemImage: "text.viewfinder",
                        description: Text("Pick a receipt photo to run OCR on it.")
                    )
                }

                Spacer()
            }
            .padding()
            .navigationTitle("OCR Test")
            .onChange(of: selectedItem) { _, newItem in
                Task { await loadAndRecognize(newItem) }
            }
        }
    }

    private func loadAndRecognize(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        errorMessage = nil
        ocrLines = []

        guard
            let data = try? await item.loadTransferable(type: Data.self),
            let uiImage = UIImage(data: data)
        else {
            errorMessage = "Couldn't load the selected photo."
            return
        }
        selectedImage = uiImage
        isProcessing = true
        defer { isProcessing = false }

        do {
            let lines = try await recognizeText(in: uiImage)
            ocrLines = lines

            // Also dump to console — handy for copy-pasting real output into a
            // later chat when refining the row-clustering or item-parsing logic.
            print("--- OCR result: \(lines.count) lines ---")
            for line in lines {
                print("[\(String(format: "%.2f", line.confidence))] \(line.text)  box=\(line.boundingBox)")
            }
        } catch {
            errorMessage = "OCR failed: \(error.localizedDescription)"
        }
    }
}

#Preview {
    OCRTestView()
}
