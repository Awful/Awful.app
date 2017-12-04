//
//  Forum+Presentation.swift
//  Awful
//
//  Created by Nolan Waite on 2017-12-03.
//  Copyright © 2017 Awful Contributors. All rights reserved.
//

import AwfulCore

extension Forum {
    var ancestors: AnySequence<Forum> {
        var current = parentForum
        return AnySequence {
            return AnyIterator {
                let next = current
                current = current?.parentForum
                return next
            }
        }
    }
}
