//
//  Base62.swift
//  Core
//
//  Created by Nolan Waite on 2017-12-03.
//  Copyright © 2017 Awful Contributors. All rights reserved.
//

/// Returns a base-62 representation of an integer. Digits are 0-9, A-Z, a-z.
internal func base62Encode<I: BinaryInteger>(_ i: I) -> String {
    let base = I(base62Alphabet.count)
    var digits: [Character] = []
    var i = i
    while i > base {
        let digit: I
        (i, digit) = i.quotientAndRemainder(dividingBy: base)
        digits.append(base62Alphabet[Int(digit)])
    }
    digits.append(base62Alphabet[Int(i)])
    return String(digits.reversed())
}

private let base62Alphabet: [Character] = [
    "0", "1", "2", "3", "4", "5", "6", "7", "8", "9",
    "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z",
    "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z"]
