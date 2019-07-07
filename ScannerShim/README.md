# ScannerShim

When you want to use `Scanner` in both iOS 12 and UIKit for Mac.

## Usage

In any given file:

```swift
import class ScannerShim.Scanner
```

Then just use `Scanner` as normal (even if you also `import Foundation`, the shim will take precedence). If and when your deployment target gets to iOS 13, you can simply remove `ScannerShim` and its `import` statements and everything should Just Work.

## Why

iOS 13 introduced a much nicer Swift API for `Foundation.Scanner` and deprecated the ickier mapped Objective-C interface. This means that only the new methods are available in UIKit for Mac, but only the old methods are available iOS 12. So we hide the differences behind a wrapper `Scanner` type.
