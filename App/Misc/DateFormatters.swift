//  DateFormatters.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation

extension DateFormatter {
    class var announcement: DateFormatter { return _regdate }
    class var postDate: DateFormatter { return _postDate }
    class var regdate: DateFormatter { return _regdate }
    class var sentDate: DateFormatter { return _postDate }
}

private let _postDate: DateFormatter = {
	let formatter = DateFormatter()
    
	// 01/02/03 16:05
	formatter.dateStyle = .short
	formatter.timeStyle = .short
    
	return formatter
}()

private let _regdate: DateFormatter = {
	let formatter = DateFormatter()
    
	// Jan 2, 2003
	formatter.dateStyle = .medium
	formatter.timeStyle = .none
    
	return formatter
}()
