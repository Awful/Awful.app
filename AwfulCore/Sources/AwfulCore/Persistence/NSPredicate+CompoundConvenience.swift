//  NSPredicate+CompoundConvenience.swift
//
//  Copyright 2020 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation

extension NSPredicate {
    static func and(_ subpredicates: [NSPredicate]) -> NSPredicate {
        NSCompoundPredicate(andPredicateWithSubpredicates: subpredicates)
    }
    static func and(_ subprecicates: NSPredicate...) -> NSPredicate {
        and(subprecicates)
    }

    static func or(_ subpredicates: [NSPredicate]) -> NSPredicate {
        NSCompoundPredicate(orPredicateWithSubpredicates: subpredicates)
    }
    static func or(_ subpredicates: NSPredicate...) -> NSPredicate {
        or(subpredicates)
    }
}
