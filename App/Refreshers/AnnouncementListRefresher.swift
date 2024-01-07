//  AnnouncementListRefresher.swift
//
//  Copyright 2017 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import CoreData
import UIKit

private let Log = Logger.get()

/// Periodically scrapes an updated list of announcements.
final class AnnouncementListRefresher {
    private let client: ForumsClient
    private let minder: RefreshMinder
    private weak var timer: Timer?
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

        guard let context = client.managedObjectContext,
            client.isLoggedIn,
            minder.shouldRefresh(.announcements)
        else {
            Log.d("can't refresh announcements yet, will try again later")
            return startTimer(reason: .failure)
        }

        Task {
            // Essential announcement information comes via forum thread lists, so we need to fetch threads from an arbitrary forum. Since forums come and go, we can't really hardcode a forum here.
            // For extra credit (?), we'll pick a random forum so we spread out our effect on "# users browsing" stats. If there's some other way to fetch the list of announcements, we should probably do that instead!
            let fetchRequest = Forum.makeFetchRequest() as! NSFetchRequest<NSManagedObjectID>
            fetchRequest.fetchLimit = 100
            fetchRequest.resultType = .managedObjectIDResultType
            guard let arbitraryForum: Forum = await context.perform({
                let forumIDs = try! context.fetch(fetchRequest)
                let arbitraryForumID = forumIDs.randomElement()
                return arbitraryForumID.map { context.object(with: $0) as! Forum }
            }) else {
                Log.d("we don't know of any forums, so we can't refresh announcements; will try again later")
                return startTimer(reason: .failure)
            }

            // SA: Requesting page -1 of a forum still fetches the announcements, but doesn't fetch any threads. Seems like it's maybe less work for the server? Definitely less work for us.
            do {
                _ = try await client.listThreads(in: arbitraryForum, tagged: nil, page: -1)
                Log.d("successfully refreshed announcements")
                minder.didRefresh(.announcements)
                startTimer(reason: .success)
            } catch {
                Log.w("error refreshing announcements, will try again later: \(error)")
                startTimer(reason: .failure)
            }
        }
    }

    private enum TimerReason {
        case initialization, success, failure, willEnterForeground
    }

    private func startTimer(reason: TimerReason) {
        let interval: TimeInterval = {
            let suggestion = minder.suggestedRefreshDate(.announcements).timeIntervalSinceNow

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

        Log.d("next automatic announcement list refresh is in \(interval) seconds")

        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] timer in
            self?.refreshIfNecessary()
        }
    }
}
