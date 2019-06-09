//  Post+Presentation.swift
//
//  Copyright 2019 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import Foundation
import HTMLReader

extension Post {

    /// A GitHub-Flavored Markdown rendering of the post suitable for pasting into GitHub issues.
    var gitHubFlavoredMarkdown: String {
        /*
         > I got this just yesterday:
         > ![image](https://user-images.githubusercontent.com/177228/53771058-9ae2c180-3eb7-11e9-8899-3584dcbdad5d.png)
         > — [The_Doctor](https://forums.somethingawful.com/showthread.php?noseen=0&threadid=3837546&perpage=40&pagenumber=43#post492763159)
         */
        /*
         TODO:
             * grab body HTML
             * deal with tags we care about (<i> -> *, <b> -> **, <a> -> [](), <img> -> ![]())
             * strip tags we don't care about
             * collapse whitespace
             * turn <br> into \n
             * Prepend lines with `> `
             * Append attribution line
         */
        let unquoted = HTMLDocument(string: "<body>\(innerHTML ?? "")").gitHubFlavoredMarkdown.trimmingCharacters(in: .whitespacesAndNewlines)
        let quoted = unquoted.replacingOccurrences(of: "\n", with: "\n> ")
        return """
            > \(quoted)
            > — [\(author?.username ?? "")](https://forums.somethingawful.com/showthread.php?threadid=\(thread?.threadID ?? "")&perpage=40&pagenumber=\(page)#post\(postID))
            """
    }
}

private extension HTMLNode {
    var childGitHubFlavoredMarkdown: [String] {
        return nodeChildren.map { $0.gitHubFlavoredMarkdown }
    }

    @objc var gitHubFlavoredMarkdown: String {
        return childGitHubFlavoredMarkdown.joined()
    }
}

private extension HTMLElement {
    override var gitHubFlavoredMarkdown: String {
        switch tagName {
        case "a":
            return "[\(childGitHubFlavoredMarkdown.joined())](\(self["href"] ?? ""))"
        case "b":
            let fragments = ["**"] + childGitHubFlavoredMarkdown + ["**"]
            return fragments.joined()
        case "br":
            return "\n"
        case "div":
            return ""
        case "i":
            let fragments = ["*"] + childGitHubFlavoredMarkdown + ["*"]
            return fragments.joined()
        case "img":
            return "![\(self["alt"] ?? "")](\(self["src"] ?? ""))"
        case "p":
            return ""
        default:
            return super.gitHubFlavoredMarkdown
        }
    }
}

private extension HTMLTextNode {
    override var gitHubFlavoredMarkdown: String {
        return textContent.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }
}
