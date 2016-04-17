//  NewThreadTagObserver.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

/// Waits for a particular new thread tag to be downloaded.
final class NewThreadTagObserver: NSObject {
    private let imageName: String
    private let downloadedBlock: UIImage -> Void
    private var observerToken: NSObjectProtocol?
    
    init(imageName: String, downloadedBlock: UIImage -> Void) {
        self.imageName = imageName
        self.downloadedBlock = downloadedBlock
        super.init()
        
        observerToken = NSNotificationCenter.defaultCenter().addObserverForName(ThreadTagLoader.newImageAvailableNotification, object: nil, queue: NSOperationQueue.mainQueue(), usingBlock: { [weak self] (notification) in
            guard let note = NewImageAvailableNotification(notification) else { return }
            self?.newThreadTagDidDownload(note)
        })
    }
    
    deinit {
        stopObserving()
    }
    
    private func stopObserving() {
        guard let token = observerToken else { return }
        NSNotificationCenter.defaultCenter().removeObserver(token)
        observerToken = nil
    }
    
    private func newThreadTagDidDownload(notification: NewImageAvailableNotification) {
        guard notification.imageName == imageName else { return }
        stopObserving()
        
        guard let image = notification.loader.imageNamed(notification.imageName) else { return }
        downloadedBlock(image)
    }
}

private struct NewImageAvailableNotification {
    let loader: ThreadTagLoader
    let imageName: String
    
    init?(_ notification: NSNotification) {
        guard notification.name == ThreadTagLoader.newImageAvailableNotification else { return nil }
        guard let
            loader = notification.object as? ThreadTagLoader,
            imageName = notification.userInfo?[ThreadTagLoader.newImageNameKey] as? String else { return nil }
        self.loader = loader
        self.imageName = imageName
    }
}
