//
//  ScannerTestView.swift
//
//  Part 2 of the native receipt scanner build plan — throwaway test screen to
//  verify capture works before OCR is built on top of it (Part 3+).
//
//  Run this on a physical device — VNDocumentCameraViewController needs a camera,
//  which the Simulator doesn't have.
//

import SwiftUI
import UIKit

struct ScannerTestView: View {
    @State private var isShowingScanner = false
    @State private var capturedImage: UIImage?

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if let capturedImage {
                    Image(uiImage: capturedImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 420)
                        .cornerRadius(12)
                        .shadow(radius: 4)
                        .overlay(alignment: .topTrailing) {
                            Button {
                                self.capturedImage = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.white, .black.opacity(0.6))
                            }
                            .padding(8)
                        }
                } else {
                    ContentUnavailableView(
                        "No Receipt Scanned",
                        systemImage: "doc.text.viewfinder",
                        description: Text("Tap the button below to scan a receipt.")
                    )
                }

                Spacer()

                Button {
                    isShowingScanner = true
                } label: {
                    Label("Scan Receipt", systemImage: "camera.viewfinder")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
            }
            .padding()
            .navigationTitle("Scanner Test")
            .fullScreenCover(isPresented: $isShowingScanner) {
                DocumentScannerView { image in
                    capturedImage = image
                }
                .ignoresSafeArea()
            }
        }
    }
}

#Preview {
    ScannerTestView()
}
