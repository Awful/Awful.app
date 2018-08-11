//  PrivateMessageInboxRefresher.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import Foundation

private let Log = Logger.get()

/// Periodically checks for new private messages in the logged-in user's inbox.
final class PrivateMessageInboxRefresher {
    private let client: ForumsClient
    private let minder: RefreshMinder
    private var timer: Timer?
    private var tokens: [NSObjectProtocol] = []
    
    init(client: ForumsClient, minder: RefreshMinder) {
        self.client = client
        self.minder = minder
        
        startTimer(reason: .initialization)
        
        tokens.append(NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: UIApplication.shared, queue: .main, using: { [unowned self] notification in
            
            self.startTimer(reason: .willEnterForeground)
        }))
        
        tokens.append(NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: UIApplication.shared, queue: .main, using: { [unowned self] notification in
            
            self.timer?.invalidate()
        }))
    }
    
    deinit {
        timer?.invalidate()
        tokens.forEach(NotificationCenter.default.removeObserver)
    }
    
    func refreshIfNecessary() {
        timer?.invalidate()
        
        guard
            client.isLoggedIn,
            AwfulSettings.shared().canSendPrivateMessages,
            minder.shouldRefresh(.privateMessagesInbox) else
        {
            Log.d("can't refresh private message inbox yet, will try again later")
            return startTimer(reason: .failure)
        }
        
        _ = client.listPrivateMessagesInInbox()
            .done { [weak self, minder] messages in
                Log.d("successfully refreshed private message inbox")
                
                minder.didRefresh(.privateMessagesInbox)
                
                self?.startTimer(reason: .success)
            }
            .catch { [weak self] error in
                Log.w("error refreshing private message inbox, will try again later: \(error)")
                
                self?.startTimer(reason: .failure)
        }
    }
    
    private enum TimerReason {
        case initialization, success, failure, willEnterForeground
    }
    
    private func startTimer(reason: TimerReason) {
        let interval: TimeInterval = {
            let suggestion = minder.suggestedRefreshDate(.privateMessagesInbox).timeIntervalSinceNow
            
            switch reason {
            case .success:
                return suggestion
                
            case .initialization where suggestion < 20,
                 .failure where suggestion <= 20,
                 .willEnterForeground where suggestion <= 20:
                // Some random time in the next couple minutes
                return 20 + TimeInterval(arc4random_uniform(90))
                
            case .initialization, .failure, .willEnterForeground:
                return suggestion
            }
        }()
        
        Log.d("next automatic private message inbox refresh is in \(interval) seconds")
        
        timer = Timer.scheduledTimerWithInterval(interval) { [weak self] timer in
            self?.refreshIfNecessary()
        }
    }
}
