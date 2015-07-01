//  DateFormatters.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation

extension NSDateFormatter {
    class func postDateFormatter() -> NSDateFormatter { return _postDateFormatter }
	class func regDateFormatter() -> NSDateFormatter { return _regDateFormatter }
}

private let _postDateFormatter: NSDateFormatter = {
	let formatter = NSDateFormatter()
    
	// 01/02/03 16:05
	formatter.dateStyle = .ShortStyle
	formatter.timeStyle = .ShortStyle
    
	return formatter
}()

private let _regDateFormatter: NSDateFormatter = {
	let formatter = NSDateFormatter()
    
	// Jan 2, 2003
	formatter.dateStyle = .MediumStyle
	formatter.timeStyle = .NoStyle
    
	return formatter
}()
