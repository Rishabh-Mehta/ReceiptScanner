// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ReceiptScannerKit",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(name: "ReceiptScannerKit", targets: ["ReceiptScannerKit"])
    ],
    targets: [
        .target(
            name: "ReceiptScannerKit"
        ),
        .testTarget(
            name: "ReceiptScannerKitTests",
            dependencies: ["ReceiptScannerKit"]
        )
    ]
)
