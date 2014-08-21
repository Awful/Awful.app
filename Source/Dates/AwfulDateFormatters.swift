//  AwfulDateFormatters.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation


private let AwfulPostDateFormatter: NSDateFormatter = {
	var formatter = NSDateFormatter()
	// Jan 2, 2003 16:05
	formatter.dateStyle = .MediumStyle
	formatter.timeStyle = .ShortStyle
	return formatter
	}()

private let AwfulRegDateFormatter: NSDateFormatter = {
	var formatter = NSDateFormatter()
	// Jan 2, 2003
	formatter.dateStyle = .MediumStyle
	formatter.timeStyle = .NoStyle
	return formatter
	}()


class AwfulDateFormatters: NSObject {
	
	class func postDateFormatter()->NSDateFormatter { return AwfulPostDateFormatter }
	
	class func regDateFormatter()->NSDateFormatter { return AwfulRegDateFormatter }
}
