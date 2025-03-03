//  ImgurAnonymousAPI+Shared.swift
//
//  Copyright 2019 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation
import ImgurAnonymousAPI
import os

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "ImgurAnonymousAPI")

extension ImgurUploader {
    static var shared: ImgurUploader {
        return sharedUploader
    }
}

private let sharedUploader: ImgurUploader = {
    ImgurUploader.logger = { level, message in
        let otherLevel: OSLogType
        switch level {
        case .debug:
            otherLevel = .debug
        case .info:
            otherLevel = .info
        case .error:
            otherLevel = .error
        }
        let message = message()
        logger.log(level: otherLevel, "\(message)")
    }
    
    return ImgurUploader(clientID: "4db466addcb5cfc")
}()
