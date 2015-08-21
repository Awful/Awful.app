//  Errors.swift
//
//  Copyright 2015 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

public class AwfulCoreError : NSObject {
    public class var domain: String { return "AwfulCoreErrorDomain" }
    
    // These error codes were ported from AwfulErrorDomain.
    public class var invalidUsernameOrPassword: Int { return 1 }
    public class var parseError: Int { return 3 }
    public class var forbidden: Int { return 3 }
    public class var databaseUnavailable: Int { return 7 }
    public class var archivesRequired: Int { return 8 }
}
