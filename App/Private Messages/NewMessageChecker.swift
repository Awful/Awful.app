//  NewMessageChecker.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import Foundation

/// Periodically checks for new private messages in the logged-in user's inbox and posts notifications.
final class NewMessageChecker: NSObject {
    static let sharedChecker = NewMessageChecker()
    private var timer: NSTimer?
    
    override init() {
        super.init()
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(applicationWillEnterForeground), name: UIApplicationWillEnterForegroundNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(applicationDidEnterBackground), name: UIApplicationDidEnterBackgroundNotification, object: nil)
    }
    
    var unreadCount: Int {
        get { return NSUserDefaults.standardUserDefaults().integerForKey(unreadCountKey) }
        set {
            NSUserDefaults.standardUserDefaults().setInteger(newValue, forKey: unreadCountKey)
            let userInfo = [NewMessageChecker.notificationUnreadCountKey: newValue]
            NSNotificationCenter.defaultCenter().postNotificationName(NewMessageChecker.didChangeNotification, object: self, userInfo: userInfo)
        }
    }
    
    func decrementUnreadCount() {
        guard unreadCount > 0 else { return }
        unreadCount -= 1
    }
    
    private func startTimer() {
        timer?.invalidate()
        let interval = RefreshMinder.sharedMinder.suggestedRefreshDate(.NewPrivateMessages).timeIntervalSinceNow
        timer = NSTimer.scheduledTimerWithInterval(interval, handler: { [weak self] timer in
            self?.refreshIfNecessary()
        })
    }
    
    func refreshIfNecessary() {
        guard RefreshMinder.sharedMinder.shouldRefresh(.NewPrivateMessages) else { return }
        AwfulForumsClient.sharedClient().countUnreadPrivateMessagesInInboxAndThen { [weak self] (error: NSError?, unreadCount) in
            if let error = error {
                print("\(#function) error checking for new private messages: \(error)")
                return
            }
            self?.unreadCount = unreadCount
            RefreshMinder.sharedMinder.didRefresh(.NewPrivateMessages)
        }
    }
    
    static let didChangeNotification = "Awful.NewMessageCheckerUnreadCountDidChangeNotification"
    static let notificationUnreadCountKey = "unreadCount"
    
    @objc private func applicationWillEnterForeground(notification: NSNotification) {
        refreshIfNecessary()
        startTimer()
    }
    
    @objc private func applicationDidEnterBackground(notification: NSNotification) {
        timer?.invalidate()
        timer = nil
    }
}

private let unreadCountKey = "AwfulUnreadMessages"
