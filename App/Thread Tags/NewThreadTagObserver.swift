//  NewThreadTagObserver.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

/// Waits for a particular new thread tag to be downloaded.
final class NewThreadTagObserver: NSObject {
    fileprivate let imageName: String
    fileprivate let downloadedBlock: (UIImage) -> Void
    fileprivate var observerToken: NSObjectProtocol?
    
    init(imageName: String, downloadedBlock: @escaping (UIImage) -> Void) {
        self.imageName = imageName
        self.downloadedBlock = downloadedBlock
        super.init()
        
        observerToken = NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: ThreadTagLoader.newImageAvailableNotification), object: nil, queue: OperationQueue.main, using: { [weak self] (notification) in
            guard let note = NewImageAvailableNotification(notification) else { return }
            self?.newThreadTagDidDownload(note)
        })
    }
    
    deinit {
        stopObserving()
    }
    
    fileprivate func stopObserving() {
        guard let token = observerToken else { return }
        NotificationCenter.default.removeObserver(token)
        observerToken = nil
    }
    
    fileprivate func newThreadTagDidDownload(_ notification: NewImageAvailableNotification) {
        guard notification.imageName == imageName else { return }
        stopObserving()
        
        guard let image = notification.loader.imageNamed(notification.imageName) else { return }
        downloadedBlock(image)
    }
}

private struct NewImageAvailableNotification {
    let loader: ThreadTagLoader
    let imageName: String
    
    init?(_ notification: Notification) {
        guard notification.name.rawValue == ThreadTagLoader.newImageAvailableNotification else { return nil }
        guard let
            loader = notification.object as? ThreadTagLoader,
            let imageName = (notification as NSNotification).userInfo?[ThreadTagLoader.newImageNameKey] as? String else { return nil }
        self.loader = loader
        self.imageName = imageName
    }
}
