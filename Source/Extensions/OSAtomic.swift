//  OSAtomic.swift
//
//  Copyright 2015 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

/// Wraps an OSSpinLock with a handy lock() method.
final class Spinlock {
    private var spinlock = OS_SPINLOCK_INIT
    
    func lock<T>(action: () -> T) -> T {
        withUnsafeMutablePointer(&spinlock, OSSpinLockLock)
        let out = action()
        withUnsafeMutablePointer(&spinlock, OSSpinLockUnlock)
        
        return out
    }
    
    // The above generic implementation occasionally befuddles the compiler when T is Void, so we'll handle that specifically with an override.
    func lock(action: () -> Void) {
        withUnsafeMutablePointer(&spinlock, OSSpinLockLock)
        action()
        withUnsafeMutablePointer(&spinlock, OSSpinLockUnlock)
    }
}
