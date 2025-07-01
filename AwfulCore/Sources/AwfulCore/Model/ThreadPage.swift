//  ThreadPage.swift
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

public enum ThreadPage: Equatable, Hashable {

    /// Not sure what the last page is, but you want it.
    case last

    /// The first page that has unread posts.
    case nextUnread

    /// A particular page in the thread.
    case specific(Int)

    /// Convenient access to the oft-used "first page".
    public static let first = ThreadPage.specific(1)

    public static func == (lhs: ThreadPage, rhs: ThreadPage) -> Bool {
        switch (lhs, rhs) {
            case (.last, .last), (.nextUnread, .nextUnread):
                return true

            case (.specific(let lhs), .specific(let rhs)):
                return lhs == rhs

            case (.last, _), (.nextUnread, _), (.specific, _):
                return false
        }
    }
}
