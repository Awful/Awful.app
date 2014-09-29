//  SmilieDownloader.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation

public protocol SmilieDownloader {
    func downloadImageDataFromURL(URL: NSURL, completionBlock: (imageData: NSData!, error: NSError!) -> Void)
}

class URLSessionSmilieDownloader: SmilieDownloader {
    lazy private var session: NSURLSession = {
        let configuration = NSURLSessionConfiguration.ephemeralSessionConfiguration()
        configuration.networkServiceType = .NetworkServiceTypeBackground
        return NSURLSession(configuration: configuration)
        }()
    
    func downloadImageDataFromURL(URL: NSURL, completionBlock: (imageData: NSData!, error: NSError!) -> Void) {
        let task = session.dataTaskWithURL(URL) { imageData, response, error in
            if let response = response as? NSHTTPURLResponse {
                if 200..<299 ~= (response as NSHTTPURLResponse).statusCode {
                    dispatch_async(dispatch_get_main_queue()) {
                        completionBlock(imageData: imageData, error: nil)
                    }
                } else {
                    let error = NSError(domain: "SmilieErrorDomain", code: 1, userInfo: ["HTTPResponseKey": response])
                    dispatch_async(dispatch_get_main_queue()) {
                        completionBlock(imageData: nil, error: error)
                    }
                }
            } else {
                let error = NSError(domain: "SmilieErrorDomain", code: 1, userInfo: [NSUnderlyingErrorKey: error])
                dispatch_async(dispatch_get_main_queue()) {
                    completionBlock(imageData: nil, error: error)
                }
            }
        }
        task.resume()
    }
}
