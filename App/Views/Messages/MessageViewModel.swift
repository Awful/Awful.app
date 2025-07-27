//  MessageViewModel.swift
//
//  Copyright 2025 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import AwfulSettings
import AwfulTheming
import Combine
import Foundation
import os

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "MessageViewModel")

@MainActor
final class MessageViewModel: NSObject, ObservableObject {
    @Published var isLoading = false
    
    private let message: PrivateMessage
    private var cancellables: Set<AnyCancellable> = []
    
    @FoilDefaultStorage(Settings.enableHaptics) var enableHaptics
    @FoilDefaultStorage(Settings.handoffEnabled) var handoffEnabled
    @FoilDefaultStorage(Settings.autoplayGIFs) private var autoplayGIFs
    @FoilDefaultStorage(Settings.embedBlueskyPosts) private var embedBlueskyPosts
    @FoilDefaultStorage(Settings.embedTweets) private var embedTweets
    @FoilDefaultStorage(Settings.fontScale) private var fontScale
    @FoilDefaultStorage(Settings.showAvatars) private var showAvatars
    @FoilDefaultStorage(Settings.loadImages) private var showImages
    
    init(message: PrivateMessage) {
        self.message = message
        super.init()
    }
    
    func loadMessageIfNeeded() async {
        // Check if we need to load message content
        guard self.message.innerHTML == nil || self.message.innerHTML?.isEmpty == true || self.message.from == nil else {
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let loadedMessage = try await ForumsClient.shared.readPrivateMessage(identifiedBy: self.message.objectKey)
            
            // Mark as seen if not already
            if loadedMessage.seen == false {
                loadedMessage.seen = true
                try await loadedMessage.managedObjectContext?.perform {
                    try loadedMessage.managedObjectContext?.save()
                }
            }
        } catch {
            logger.error("Failed to load message: \(error)")
        }
    }
}