// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ReceiptScannerKit",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(name: "ReceiptScannerKit", type: .static, targets: ["ReceiptScannerKit"])
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