import AwfulCore

// Temporary shim: legacy profile code expects these properties on `User`.
// They are no longer provided by the data model; until the feature is reimplemented,
// provide nil fallbacks so the app still compiles and runs.
public extension User {
    /// The ID of the thread containing the user's most recent post.
    /// Not currently backed by data; always `nil`.
    var lastPostThreadID: String? { nil }
    /// The page number (1-based) of the thread containing the user's most recent post.
    /// Not currently backed by data; always `nil`.
    var lastPostPage: Int? { nil }
    /// The post ID of the user's most recent post.
    /// Not currently backed by data; always `nil`.
    var lastPostID: String? { nil }
} 