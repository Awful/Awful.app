//  KVOControllerExtensions.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

// (The change in callback type distinguishes these methods from their untyped friends.)
extension FBKVOController {
    /// Registers observer for Key-Value Observation, preserving the type of the observed object through the callback. Note the callback block takes only two parameters; use a capture list to keep a reference to the observer.
    func observe<T: AnyObject>(typedObject: T, keyPath: String, options: NSKeyValueObservingOptions, block: (object: T, change: [NSObject:AnyObject]) -> Void) {
        observe(typedObject, keyPath: keyPath, options: options) { observer, untypedObject, change in
            block(object: untypedObject as T, change: change)
            return
        }
    }
    
    /// Registers observer for Key-Value Observation, preserving the type of the observed object through the callback. Note the callback block only takes two paramters; use a capture list to keep a reference to the observer.
    func observe<T: AnyObject>(typedObject: T, keyPaths: [String], options: NSKeyValueObservingOptions, block: (object: T, change: [NSObject:AnyObject]) -> Void) {
        observe(typedObject, keyPaths: keyPaths, options: options) { observer, untypedObject, change in
            block(object: untypedObject as T, change: change)
            return
        }
    }
}
