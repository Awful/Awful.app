if (window.top === window) {
    safari.self.addEventListener("message", event => {
        switch (event.name) {
            case "copyMarkdown":
                copyMarkdown(event);
                break;
            default:
                console.log(`unexpected message ${event.name}`);
                break;
        }
    });
}

function copyMarkdown(event) {
    const selection = window.getSelection();
    const anchor = selection.anchorNode;
    if (anchor == null) return;

    const post = (anchor.closest ? anchor : anchor.parentElement).closest('table.post');

    const postbody = post.querySelector('td.postbody');
    const body = markdownifyChildren(postbody);

    const author = post.querySelector('dl.userinfo dt.author').textContent;
    const link = post.querySelector('td.postdate a[href ^= "#post"]');
    const url = link != null ? link.href : window.location;
    const attribution = `— [${author}](${url})`;

    const unquoted = body + "\n" + attribution;
    const markdown = '> ' + unquoted.replace(/\n/g, "\n> ");
    safari.extension.dispatchMessage("setPasteboard", {text: markdown});

    function markdownify(node) {
        switch (node.nodeType) {
            case Node.ELEMENT_NODE:
                switch (node.tagName) {
                    case 'A':
                        return `[${markdownifyChildren(node)}](${node.href || ""})`;
                    case 'B':
                        return `**${markdownifyChildren(node)}**`;
                    case 'BR':
                        return `\n`;
                    case 'DIV':
                        return ``;
                    case 'I':
                        return `*${markdownifyChildren(node)}*`;
                    case 'IMG':
                        if (isSmilie(node)) {
                            return node.alt.trim();
                        }
                        return `![${node.alt.trim() || ""}](${node.src || ""})`;
                    case 'OL':
                        return `\n${markdownifyListItems(node, "1.")}\n`;
                    case 'P':
                        return ``;
                    case 'UL':
                        return `\n${markdownifyListItems(node, "-")}\n`;
                    default:
                        return markdownifyChildren(node);
                }

            case Node.TEXT_NODE:
                return node.textContent.replace(/\s+/g, ' ').trim();
        }
    }

    function markdownifyChildren(node) {
        return Array.from(node.childNodes).map(markdownify).join("");
    }

    function markdownifyListItems(node, prefix) {
        return Array.from(node.childNodes)
            .filter(n => n.tagName == 'LI')
            .map(n => `${prefix} ${markdownify(n)}`)
            .join("");
    }

    function isSmilie(img) {
        if (!img.alt) return false;
        let url;
        try {
            url = new URL(img.src || "");
        } catch {
            return false;
        }
        const pathComponents = url.pathname.split('/');
        switch (url.host.toLowerCase()) {
            case 'fi.somethingawful.com':
                return (pathComponents.includes("smilies")
                    || pathComponents.includes("posticons")
                    || pathComponents.includes("customtitles"));
            case 'i.somethingawful.com':
                return (pathComponents.includes("emot")
                    || pathComponents.includes("emoticons")
                    || pathComponents.includes("images")
                    || (pathComponents.includes("u")
                        && (pathComponents.includes("adminuploads")
                            || pathComponents.includes("garbageday"))));
            case 'forumimages.somethingawful.com':
                return (pathComponents[1] == "images"
                    || pathComponents.includes("posticons"));
            default:
                return false
        }
    }
}
