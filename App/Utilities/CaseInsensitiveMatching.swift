//  CaseInsensitiveMatching.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

struct CaseInsensitive {
    let string: String
    init(_ string: String) {
        self.string = string
    }
}

func ~=(pattern: String?, predicate: CaseInsensitive) -> Bool {
    return pattern?.caseInsensitiveCompare(predicate.string) == .OrderedSame
}
