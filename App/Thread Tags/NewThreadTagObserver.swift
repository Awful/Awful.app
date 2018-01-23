//  NewThreadTagObserver.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

/// Waits for a particular new thread tag to be downloaded.
final class NewThreadTagObserver {
    private let imageName: String
    private let downloadedBlock: (UIImage) -> Void
    private var observerToken: NSObjectProtocol?
    
    init(imageName: String, downloadedBlock: @escaping (UIImage) -> Void) {
        self.imageName = imageName
        self.downloadedBlock = downloadedBlock

        observerToken = NotificationCenter.default.addObserver(forName: ThreadTagLoader.NewImageAvailableNotification.name, object: ThreadTagLoader.sharedLoader, queue: .main, using: { [weak self] notification in
            self?.newThreadTagDidDownload(ThreadTagLoader.NewImageAvailableNotification(notification))
        })
    }
    
    deinit {
        stopObserving()
    }
    
    private func stopObserving() {
        guard let token = observerToken else { return }
        NotificationCenter.default.removeObserver(token)
        observerToken = nil
    }
    
    private func newThreadTagDidDownload(_ notification: ThreadTagLoader.NewImageAvailableNotification) {
        guard notification.newImageName == imageName else { return }
        stopObserving()
        
        guard let image = ThreadTagLoader.sharedLoader.imageNamed(notification.newImageName) else { return }
        downloadedBlock(image)
    }
}
