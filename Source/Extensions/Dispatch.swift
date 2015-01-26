//  Dispatch.swift
//
//  Copyright 2015 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

/// Submits block for execution on the main queue and returns immediately.
func dispatch_main_async(block: dispatch_block_t) {
    dispatch_async(dispatch_get_main_queue(), block)
}
