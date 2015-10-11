//  Foundation.swift
//
//  Copyright 2015 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation

extension NSTimer {
    class func scheduledTimerWithTimeInterval(timeInterval: NSTimeInterval, handler: NSTimer -> Void) -> NSTimer {
        return CFRunLoopTimerCreateWithHandler(nil, CFAbsoluteTimeGetCurrent() + timeInterval, 0, 0, 0) { timer in
            handler(timer)
        }
    }
}
