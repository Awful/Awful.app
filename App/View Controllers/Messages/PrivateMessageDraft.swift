//  PrivateMessageDraft.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import Foundation

/// On-disk draft for an in-progress private message, recovered when the user re-opens the
/// matching compose flow (new PM, reply to a specific PM, or forward of a specific PM).
@objc(PrivateMessageDraft)
final class PrivateMessageDraft: NSObject, NSCoding, StorableDraft {
    enum Kind {
        /// Blank new message with no pre-filled recipient.
        case new
        /// New message addressed to the given user.
        case to(User)
        /// Reply to the given message.
        case replying(to: PrivateMessage)
        /// Forward of the given message.
        case forwarding(PrivateMessage)
    }

    let kind: Kind
    var to: String
    var subject: String
    var threadTag: ThreadTag?
    var text: NSAttributedString?

    init(kind: Kind) {
        self.kind = kind
        self.to = ""
        self.subject = ""
        super.init()
    }

    var storePath: String {
        switch kind {
        case .new:
            return "messages/new"
        case .to(let user):
            return "messages/to/\(user.userID)"
        case .replying(let message):
            return "messages/replying/\(message.messageID)"
        case .forwarding(let message):
            return "messages/forwarding/\(message.messageID)"
        }
    }

    private enum CoderKey {
        static let kind = "kind"
        static let messageKey = "messageKey"
        static let userKey = "userKey"
        static let to = "to"
        static let subject = "subject"
        static let threadTagKey = "threadTagKey"
        static let text = "text"
    }

    private enum KindRawValue: Int {
        case new = 0
        case replying = 1
        case forwarding = 2
        case to = 3
    }

    convenience init?(coder: NSCoder) {
        let context = AppDelegate.instance.managedObjectContext
        let rawKind = coder.decodeInteger(forKey: CoderKey.kind)
        let kind: Kind
        switch KindRawValue(rawValue: rawKind) {
        case .new, nil:
            kind = .new
        case .to:
            guard let key = coder.decodeObject(forKey: CoderKey.userKey) as? UserKey else {
                return nil
            }
            kind = .to(User.objectForKey(objectKey: key, in: context))
        case .replying:
            guard let key = coder.decodeObject(forKey: CoderKey.messageKey) as? PrivateMessageKey else {
                return nil
            }
            kind = .replying(to: PrivateMessage.objectForKey(objectKey: key, in: context))
        case .forwarding:
            guard let key = coder.decodeObject(forKey: CoderKey.messageKey) as? PrivateMessageKey else {
                return nil
            }
            kind = .forwarding(PrivateMessage.objectForKey(objectKey: key, in: context))
        }

        self.init(kind: kind)
        self.to = (coder.decodeObject(forKey: CoderKey.to) as? String) ?? ""
        self.subject = (coder.decodeObject(forKey: CoderKey.subject) as? String) ?? ""
        if let tagKey = coder.decodeObject(forKey: CoderKey.threadTagKey) as? ThreadTagKey {
            self.threadTag = ThreadTag.objectForKey(objectKey: tagKey, in: context)
        }
        self.text = coder.decodeObject(forKey: CoderKey.text) as? NSAttributedString
    }

    func encode(with coder: NSCoder) {
        let rawKind: KindRawValue
        switch kind {
        case .new:
            rawKind = .new
        case .to(let user):
            rawKind = .to
            coder.encode(user.objectKey, forKey: CoderKey.userKey)
        case .replying(let message):
            rawKind = .replying
            coder.encode(message.objectKey, forKey: CoderKey.messageKey)
        case .forwarding(let message):
            rawKind = .forwarding
            coder.encode(message.objectKey, forKey: CoderKey.messageKey)
        }
        coder.encode(rawKind.rawValue, forKey: CoderKey.kind)
        coder.encode(to, forKey: CoderKey.to)
        coder.encode(subject, forKey: CoderKey.subject)
        coder.encode(threadTag?.objectKey, forKey: CoderKey.threadTagKey)
        coder.encode(text, forKey: CoderKey.text)
    }
}
