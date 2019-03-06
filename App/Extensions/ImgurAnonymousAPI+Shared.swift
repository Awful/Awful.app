//  ImgurAnonymousAPI+Shared.swift
//
//  Copyright 2019 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import ImgurAnonymousAPI

private let Log = Logger.get()

extension ImgurUploader {
    static var shared: ImgurUploader {
        return sharedUploader
    }
}

private let sharedUploader: ImgurUploader = {
    ImgurUploader.logger = { level, message in
        let otherLevel: Logger.Level
        switch level {
        case .debug:
            otherLevel = .debug
        case .info:
            otherLevel = .info
        case .error:
            otherLevel = .error
        }
        Log.log(level: otherLevel, message: message, file: #file, line: #line)
    }
    
    return ImgurUploader(clientID: "4db466addcb5cfc")
}()
