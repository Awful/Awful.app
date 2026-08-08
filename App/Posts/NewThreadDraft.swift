//  NewThreadDraft.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import Foundation

/// On-disk draft for an in-progress new thread, recovered when the user re-opens the compose
/// flow on the same forum.
@objc(NewThreadDraft)
final class NewThreadDraft: NSObject, NSCoding, StorableDraft {
    let forum: Forum
    var subject: String
    var threadTag: ThreadTag?
    var secondaryThreadTag: ThreadTag?
    var text: NSAttributedString?
    var poll: PollSubmission?

    init(forum: Forum) {
        self.forum = forum
        self.subject = ""
        super.init()
    }

    var storePath: String {
        return "newThreads/\(forum.forumID)"
    }

    private enum Keys {
        static let forumKey = "forumKey"
        static let subject = "subject"
        static let threadTagKey = "threadTagKey"
        static let secondaryThreadTagKey = "secondaryThreadTagKey"
        static let text = "text"
        static let poll = "poll"
    }

    convenience init?(coder: NSCoder) {
        guard let forumKey = coder.decodeObject(forKey: Keys.forumKey) as? ForumKey else {
            return nil
        }
        let context = AppDelegate.instance.managedObjectContext
        let forum = Forum.objectForKey(objectKey: forumKey, in: context)
        self.init(forum: forum)
        self.subject = (coder.decodeObject(forKey: Keys.subject) as? String) ?? ""
        if let tagKey = coder.decodeObject(forKey: Keys.threadTagKey) as? ThreadTagKey {
            self.threadTag = ThreadTag.objectForKey(objectKey: tagKey, in: context)
        }
        if let secondaryKey = coder.decodeObject(forKey: Keys.secondaryThreadTagKey) as? ThreadTagKey {
            self.secondaryThreadTag = ThreadTag.objectForKey(objectKey: secondaryKey, in: context)
        }
        self.text = coder.decodeObject(forKey: Keys.text) as? NSAttributedString
        // Drafts archived before polls existed simply have no value here. Decoding must never
        // throw: `init?(coder:)` returning nil throws away the whole draft, poll or not.
        self.poll = (coder.decodeObject(forKey: Keys.poll) as? Data)
            .flatMap { try? JSONDecoder().decode(PollSubmission.self, from: $0) }
    }

    func encode(with coder: NSCoder) {
        coder.encode(forum.objectKey, forKey: Keys.forumKey)
        coder.encode(subject, forKey: Keys.subject)
        coder.encode(threadTag?.objectKey, forKey: Keys.threadTagKey)
        coder.encode(secondaryThreadTag?.objectKey, forKey: Keys.secondaryThreadTagKey)
        coder.encode(text, forKey: Keys.text)
        if let poll, let data = try? JSONEncoder().encode(poll) {
            coder.encode(data, forKey: Keys.poll)
        }
    }
}
