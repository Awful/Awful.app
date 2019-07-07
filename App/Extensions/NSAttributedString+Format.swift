//  NSAttributedString+Format.swift
//
//  Copyright 2018 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation
import class ScannerShim.Scanner

extension NSMutableAttributedString {
    
    /**
     Creates an attributed string by replacing instances of `%@` or `%n$@` in `format` with the appropriate element from `args`.
     
     It is a programmer error if `format` specifies an element that does not exist in `args`.
     
     - Warning: No format specifiers are supported other than `@` (and `%` to escape a percent sign).
     */
    convenience init(format: NSAttributedString, _ args: NSAttributedString...) {
        self.init(attributedString: format)
        
        func makeScanner(at index: String.Index) -> Scanner {
            let scanner = Scanner(string: string)
            scanner.caseSensitive = false
            scanner.charactersToBeSkipped = nil
            scanner.currentIndex = index
            return scanner
        }
        
        var scanner = makeScanner(at: string.startIndex)
        
        var unindexedArgs = args.makeIterator()
        
        while true {
            
            // Find next %
            _ = scanner.scanUpToString("%")
            let specifierStartIndex = scanner.currentIndex
            
            // If we didn't find one, we're done!
            guard scanner.scanString("%") != nil else { break }
            
            // Might just be a %-escaped %.
            if scanner.scanString("%") != nil {
                continue
            }
            
            let replacement: NSAttributedString
            if
                let i = scanner.scanInt(),
                scanner.scanString("$") != nil,
                scanner.scanString("@") != nil
            {
                // Format specifiers are 1-indexed.
                replacement = args[i - 1]
            }
            else if scanner.scanString("@") != nil {
                replacement = unindexedArgs.next()!
            }
            else {
                fatalError("unsupported format specifier in \(scanner.string) at index \(scanner.currentIndex)")
            }
            
            let specifierRange = NSRange(
                location: specifierStartIndex.utf16Offset(in: scanner.string),
                length: scanner.string.distance(from: specifierStartIndex, to: scanner.currentIndex))
            replaceCharacters(in: specifierRange, with: replacement)
            
            scanner = makeScanner(at: string.index(specifierStartIndex, offsetBy: replacement.length))
        }
    }
}
