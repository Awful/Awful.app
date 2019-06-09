//  NSAttributedString+Format.swift
//
//  Copyright 2018 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation

extension NSMutableAttributedString {
    
    /**
     Creates an attributed string by replacing instances of `%@` or `%n$@` in `format` with the appropriate element from `args`.
     
     It is a programmer error if `format` specifies an element that does not exist in `args`.
     
     - Warning: No format specifiers are supported other than `@` (and `%` to escape a percent sign).
     */
    convenience init(format: NSAttributedString, _ args: NSAttributedString...) {
        self.init(attributedString: format)
        
        func makeScanner(at scanLocation: Int) -> Scanner {
            let scanner = Scanner(string: string)
            scanner.caseSensitive = false
            scanner.charactersToBeSkipped = nil
            scanner.scanLocation = scanLocation
            return scanner
        }
        
        var scanner = makeScanner(at: 0)
        
        var unindexedArgs = args.makeIterator()
        
        while true {
            
            // Find next %
            _ = scanner.scanUpTo("%")
            let specifierStartLocation = scanner.scanLocation
            
            // If we didn't find one, we're done!
            guard scanner.scan("%") else { break }
            
            // Might just be a %-escaped %.
            if scanner.scan("%") {
                continue
            }
            
            let replacement: NSAttributedString
            if
                let i = scanner.scanInt(),
                scanner.scan("$"),
                scanner.scan("@")
            {
                // Format specifiers are 1-indexed.
                replacement = args[i - 1]
            }
            else if scanner.scan("@") {
                replacement = unindexedArgs.next()!
            }
            else {
                fatalError("unsupported format specifier in \(scanner.string) at index \(scanner.scanLocation)")
            }
            
            let specifierRange = NSRange(location: specifierStartLocation, length: scanner.scanLocation - specifierStartLocation)
            replaceCharacters(in: specifierRange, with: replacement)
            
            scanner = makeScanner(at: specifierStartLocation + replacement.length)
        }
    }
}
