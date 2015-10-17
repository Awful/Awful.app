//  KVOController.swift
//
//  Copyright 2015 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import KVOController

extension FBKVOController {
    typealias Change = [NSObject: AnyObject]
    
    /**
    Swift-convenient overload that:
    
    - Maintains the observee's type through to the block.
    - Makes `options` an optional parameter.
    - Skips passing the observer to the block in lieu of Swift's capture lists.
    
    See observe(_:keyPath:options:block:).
    */
    func observe<Observee: AnyObject>(object: Observee, keyPath: String, options: NSKeyValueObservingOptions = [], typedBlock: (Observee, Change) -> Void) {
        observe(object, keyPath: keyPath, options: options) { [unowned object] _, _, change in
            typedBlock(object, change)
        }
    }
    
    /**
    Swift-convenient overload that:
    
    - Maintains the observee's type through to the block.
    - Makes `options` an optional parameter.
    - Skips passing the observer to the block in lieu of Swift's capture lists.
    
    See observe(_:keyPaths:options:block:).
    */
    func observe<Observee: AnyObject>(object: Observee, keyPaths: [String], options: NSKeyValueObservingOptions = [], typedBlock: (Observee, Change) -> Void) {
        observe(object, keyPaths: keyPaths, options: options) { [unowned object] _, _, change in
            typedBlock(object, change)
        }
    }
}
