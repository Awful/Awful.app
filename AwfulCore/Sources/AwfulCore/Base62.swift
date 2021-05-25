//  Base62.swift
//
//  Copyright 2018 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

/// Returns a base-62 representation of an integer. Digits are 0-9, A-Z, a-z.
internal func base62Encode<I: BinaryInteger>(_ i: I) -> String {
    precondition(i >= 0, "negative numbers cannot be represented in base62")
    
    let base = I(base62Alphabet.count)
    var digits: [Character] = []
    var i = i
    
    while i >= base {
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
