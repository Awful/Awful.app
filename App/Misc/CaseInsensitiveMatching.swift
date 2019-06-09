//  CaseInsensitiveMatching.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

/**
 Wraps a `String` for case-insensitive matching in a `switch` statement.

 See `String.caseInsensitive` for example usage.
 */
struct CaseInsensitive {
    private let string: String

    init(_ string: String) {
        self.string = string
    }

    static func ~= (pattern: String?, predicate: CaseInsensitive) -> Bool {
        return pattern?.caseInsensitiveCompare(predicate.string) == .orderedSame
    }

    static func == (lhs: CaseInsensitive, rhs: String) -> Bool {
        return lhs.string.caseInsensitiveCompare(rhs) == .orderedSame
    }
}

extension String {

    /**
     Returns a case-insensitive wrapper around the string suitable for a `switch` statement.

     For example:

         let scheme = "awFUL"
         switch scheme.caseInsensitive {
         case "awful":
             print("Awful scheme!")
         case "http", "https":
             print("Hypertext Transfer Protocol!")
         default:
             break
         }
         // Prints "Awful scheme!"


     There's also an equality operator if that makes something easier:

         if scheme.caseInsensitive == "awful" {
             print("hooray!")
         }
         // Prints "hooray!"
     */
    var caseInsensitive: CaseInsensitive {
        return CaseInsensitive(self)
    }
}
