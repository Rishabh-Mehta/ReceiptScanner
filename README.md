# ReceiptScannerKit

Native, on-device receipt scanning pipeline (Vision OCR → row clustering → item
parsing → store/date extraction → offline categorization) for SwiftUI, iOS 17+.

## What's here

- `Sources/ReceiptScannerKit/` — all 9 parts of the pipeline, plus three
  throwaway test-harness screens (`ScannerTestView`, `OCRTestView`,
  `ReceiptScanTestView`) used to verify each stage against real photos.
- `Tests/ReceiptScannerKitTests/` — unit tests for the pure-logic parts (row
  clustering, item parsing, metadata extraction, categorization). These don't
  need a camera or a real device — they run against fabricated data.
- `.github/workflows/test.yml` — runs the tests automatically on every push,
  using GitHub's free macOS CI runners (free for public repos).

## Push this to GitHub

```bash
cd ReceiptScannerProject
git init
git add .
git commit -m "Receipt scanner pipeline - parts 1-9"
git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO.git
git branch -M main
git push -u origin main
```

Make the repo **public** — that's what makes the macOS Actions minutes free.
Then check the **Actions** tab on GitHub after pushing: a green check means
everything compiled and every test in Tests/ passed for real, on an actual
Xcode toolchain, without you needing a Mac.

## What CI can't verify

Anything involving the actual camera — `DocumentScannerView` (Part 2) and the
OCR/scan flow end to end (Parts 3, 8, 9) — since the iOS Simulator has no
camera. Those will compile successfully in CI (proving the code is valid
Swift/SwiftUI/VisionKit), but only a real device can actually run them. See
the native-receipt-scanner-build-plan.md doc for options on testing that part
without owning a Mac.

## If a test fails

The failing assertion and its message will be in the Actions log directly —
that tells you exactly which part needs another look, not just that
"something" broke.
