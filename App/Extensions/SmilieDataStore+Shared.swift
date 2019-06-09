//  SmilieDataStore+Shared.swift
//
//  Copyright 2019 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Smilies

extension SmilieDataStore {
    static var shared: SmilieDataStore { return _shared }
}

private let _shared = SmilieDataStore()
