//  NewMessageChecker.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import Foundation

/// Periodically checks for new private messages in the logged-in user's inbox and posts notifications.
final class NewMessageChecker: NSObject {
    static let sharedChecker = NewMessageChecker()
    fileprivate var timer: Timer?
    
    override init() {
        super.init()
        
        NotificationCenter.default.addObserver(self, selector: #selector(applicationWillEnterForeground), name: NSNotification.Name.UIApplicationWillEnterForeground, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidEnterBackground), name: NSNotification.Name.UIApplicationDidEnterBackground, object: nil)
    }
    
    var unreadCount: Int {
        get { return UserDefaults.standard.integer(forKey: unreadCountKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: unreadCountKey)
            let userInfo = [NewMessageChecker.notificationUnreadCountKey: newValue]
            NotificationCenter.default.post(name: Notification.Name(rawValue: NewMessageChecker.didChangeNotification), object: self, userInfo: userInfo)
        }
    }
    
    func decrementUnreadCount() {
        guard unreadCount > 0 else { return }
        unreadCount -= 1
    }
    
    fileprivate func startTimer() {
        timer?.invalidate()
        let interval = RefreshMinder.sharedMinder.suggestedRefreshDate(.newPrivateMessages).timeIntervalSinceNow
        timer = Timer.scheduledTimerWithInterval(interval, handler: { [weak self] timer in
            self?.refreshIfNecessary()
        })
    }
    
    func refreshIfNecessary() {
        guard RefreshMinder.sharedMinder.shouldRefresh(.newPrivateMessages) else { return }
        _ = ForumsClient.shared.countUnreadPrivateMessagesInInbox { [weak self] (error: Error?, unreadCount) in
            if let error = error {
                print("\(#function) error checking for new private messages: \(error)")
                return
            }
            if let unreadCount = unreadCount {
                self?.unreadCount = unreadCount
            }
            RefreshMinder.sharedMinder.didRefresh(.newPrivateMessages)
        }
    }
    
    static let didChangeNotification = "Awful.NewMessageCheckerUnreadCountDidChangeNotification"
    static let notificationUnreadCountKey = "unreadCount"
    
    @objc fileprivate func applicationWillEnterForeground(_ notification: Notification) {
        refreshIfNecessary()
        startTimer()
    }
    
    @objc fileprivate func applicationDidEnterBackground(_ notification: Notification) {
        timer?.invalidate()
        timer = nil
    }
}

private let unreadCountKey = "AwfulUnreadMessages"
