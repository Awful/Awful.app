//
//  ImgurAnonymousAPI+Shared.swift
//  Awful
//
//  Created by Nolan Waite on 2019-01-29.
//  Copyright © 2019 Awful Contributors. All rights reserved.
//

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
