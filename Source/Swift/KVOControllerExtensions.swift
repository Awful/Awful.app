//  KVOControllerExtensions.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

extension FBKVOController {
    /// Registers observer for Key-Value Observation, preserving the type of the observed object through the callback. Note the callback block takes only two parameters; use a Swift capture list to keep a reference to the observer.
    // (Also, the change in callback type distinguishes this method from its untyped friends, allowing method resolution to work nicely.)
    func observe<T: AnyObject>(typedObject: T, keyPath: String, options: NSKeyValueObservingOptions, block: (object: T, change: [NSObject:AnyObject]) -> Void) {
        observe(typedObject, keyPath: keyPath, options: options) { observer, untypedObject, change in
            block(object: untypedObject as T, change: change)
            return
        }
    }
}
