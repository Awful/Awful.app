//
//  AwfulDateFormatters.swift
//  Awful
//
//  Created by Chris on 6/7/14.
//  Copyright (c) 2014 Awful Contributors. All rights reserved.
//

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
