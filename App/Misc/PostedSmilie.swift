//  PostedSmilie.swift
//
//  Copyright 2019 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

/// A smilie found in a post (or PM, or announcement, etc.)
struct PostedSmilie {
    let imageURL: URL

    /// What to type in a post to insert the smilie.
    let text: String
}

extension PostedSmilie {

    /// Returns `true` when `url` appears to be a smilie hosted on Something Awful Forums servers.
    static func isSmilieURL(_ url: URL) -> Bool {
        guard let host = url.host else { return false }
        let components = url.pathComponents

        var fiComponents: Bool {
            return components.contains("smilies")
                || components.contains("posticons")
                || components.contains("customtitles")
        }

        var forumimagesComponents: Bool {
            return components.first == "images"
                || components.contains("posticons")
        }

        var iComponents: Bool {
            return components.contains("emot")
                || components.contains("emoticons")
                || components.contains("images")
                || (components.contains("u")
                    && (components.contains("adminuploads")
                        || components.contains("garbageday")))
        }

        switch host.caseInsensitive {
        case "fi.somethingawful.com" where fiComponents,
             "i.somethingawful.com" where iComponents,
             "forumimages.somethingawful.com" where forumimagesComponents:
            return true

        default:
            return false
        }
    }

    init?(title: String = "", url: URL) {
        guard PostedSmilie.isSmilieURL(url) else { return nil }

        imageURL = url
        self.text = title
    }
}
