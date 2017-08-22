//  DateFormatters.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation

extension DateFormatter {
    class var postDateFormatter: DateFormatter { return _postDateFormatter }
    class var regDateFormatter: DateFormatter { return _regDateFormatter }
}

private let _postDateFormatter: DateFormatter = {
	let formatter = DateFormatter()
    
	// 01/02/03 16:05
	formatter.dateStyle = .short
	formatter.timeStyle = .short
    
	return formatter
}()

private let _regDateFormatter: DateFormatter = {
	let formatter = DateFormatter()
    
	// Jan 2, 2003
	formatter.dateStyle = .medium
	formatter.timeStyle = .none
    
	return formatter
}()
