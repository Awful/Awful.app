# Embedded Tweets

The application can identify links to tweets within a forum post and replace them with rich, embedded content. This entire process is handled on the client-side within the `WKWebView` that displays posts, using a combination of Swift calls and a custom JavaScript file.

## Components

-   **`RenderView.swift`**: The `WKWebView` wrapper. It exposes an `embedTweets()` method to Swift, which triggers the JavaScript logic.
-   **`PostsPageViewController.swift` / `MessageViewController.swift`**: These view controllers host the `RenderView`. They observe the `embedTweets` setting in `UserDefaults` and call `renderView.embedTweets()` when appropriate.
-   **`RenderView.js`**: A JavaScript file that is injected into the `WKWebView`. It contains all the client-side logic for finding and embedding tweets.
-   **`Themes.plist` / `_dead-tweet-ghost.less`**: Theme files that define the appearance of embedded tweets, including a special style for "dead" (deleted or unavailable) tweets, which features a Lottie animation of a ghost.

## Tweet Embedding Workflow

The embedding process is kicked off after the main post content has been loaded into the web view.

1.  **Swift Trigger**: `PostsPageViewController` checks if the `embedTweets` setting is enabled. If so, it calls `renderView.embedTweets()`, which in turn executes `Awful.embedTweets()` in the JavaScript environment.
2.  **Load Twitter Widget Script**: The JavaScript first ensures that Twitter's `widgets.js` library is loaded. This script is responsible for the final styling and interactive rendering of the tweet.
3.  **Find Tweet Links**: The script queries the DOM for all `<a>` tags that have a `data-tweet-id` attribute. These attributes are added by the forum's backend when it renders a post.
4.  **Fetch via JSONP**: For each unique tweet ID, the script uses the **JSONP** (JSON with Padding) technique to fetch the tweet's oEmbed data. It does this by dynamically creating a `<script>` tag pointing to Twitter's v1 oEmbed API (`https://api.twitter.com/1/statuses/oembed.json`).
5.  **Handle Response**:
    -   **Success**: The JSONP callback function receives the embeddable HTML for the tweet. The script then creates a `<div>`, injects this HTML, and replaces the original link with the new `<div>`.
    -   **Failure**: If the script fails to load (e.g., the tweet has been deleted, the API is down), the `onerror` handler is triggered. It replaces the link with a "dead tweet" placeholder, which is styled with a custom CSS class and includes a Lottie animation of a ghost.
6.  **Render Widgets**: After all API requests have been attempted, the script calls `twttr.widgets.load()`. This prompts the `widgets.js` library to scan the document and transform the placeholder HTML into fully rendered, interactive tweet embeds.
7.  **Notify Swift**: Once the `widgets.js` library finishes rendering, it fires a `loaded` event. The script listens for this and sends a `didFinishLoadingTweets` message back to the native `RenderView`, signaling that the process is complete.

## Modernization Plan

The current implementation is clever but relies on a **deprecated and non-functional Twitter v1 API**. To restore this feature, the entire data fetching mechanism needs to be replaced.

-   **Replace JSONP with a Modern API**: The JSONP approach should be replaced entirely. The app should use a modern alternative, such as the official Twitter/X v2 API or a third-party service like [FixTweet](https://fxtwitter.com/) or [VX Twitter](https://vxtwitter.com/), which provide oEmbed-like responses for tweets.
-   **Server-Side vs. Client-Side Fetching**:
    -   **Client-Side (Recommended)**: The `Awful.fetchOEmbed` function in `RenderView.js`, which is already used for Bluesky embeds, provides a perfect model. The `Awful.embedTweets` function should be refactored to use this `fetch` method, calling out to a modern tweet embedding service's API endpoint. This keeps the logic self-contained within the web view.
    -   **Native (Alternative)**: Alternatively, the app could perform the API calls in native Swift code using `URLSession` and then inject the resulting HTML into the web view. This would be more complex to manage but would move the networking logic out of JavaScript.
-   **Remove Twitter v1 Code**: All code related to JSONP callbacks (`window[callback] = ...`), dynamic `<script>` tag creation for `api.twitter.com`, and the `widgets.js` loader should be removed. The new approach of injecting the final HTML directly (as done with Bluesky) makes `widgets.js` unnecessary. 