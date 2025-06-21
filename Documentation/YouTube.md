# Embedded YouTube Videos

The application handles embedded YouTube videos, but its mechanism is fundamentally different from how it handles embedded tweets. The embedding is performed by the Something Awful forums server, not by client-side code in the app.

## Data Flow: Server-Side Embedding

1.  A user includes a YouTube link or a `[video]` BBcode tag in a post.
2.  When another user views that post, the Something Awful forums backend processes the post content.
3.  The server identifies the YouTube link and replaces it with a standard HTML `<iframe>` tag pointing to YouTube's embedded player (`youtube-nocookie.com`).
4.  The Awful app downloads the post content as HTML, which already contains this `<iframe>` tag.
5.  The `WKWebView` (`RenderView`) in the app simply renders the received HTML, displaying the YouTube player as part of the post's content.

There is no client-side JavaScript in `RenderView.js` that finds and replaces YouTube links. The work is already done by the time the app receives the content.

## App-Specific Feature: Open in YouTube

While the app does not perform the embedding, it does have one piece of related, client-side functionality:

-   **Setting**: In the app's settings, there is a toggle labeled "Open YouTube in YouTube".
-   **Functionality**: When this setting is enabled, the app will intercept any navigation attempts to a `youtube.com` URL. Instead of opening the link in the in-app web browser, it will open the link in the native YouTube iOS app, if it is installed. If the setting is disabled, or the YouTube app is not installed, the link will open in the in-app browser as normal.

## Modernization Plan

Since the embedding logic is entirely server-side, there is no direct component to modernize in the same way as the tweet embedding. The `<iframe>` is standard HTML and renders perfectly well in a `WKWebView`.

However, if the goal were to create a more native-feeling experience, a future modernization project could involve:

1.  **Disabling Server-Side Embeds**: If possible, signal to the server to *not* embed videos, and instead send the raw `youtube.com` link.
2.  **Native Player**: Use client-side logic (either in Swift or JavaScript) to find these `youtube.com` links.
3.  **Replace with Thumbnail**: Replace the link with a high-resolution thumbnail image of the video, overlaid with a "play" icon. This avoids loading the heavy `<iframe>` and associated web content for every video in a thread, improving performance.
4.  **Native Playback**: When a user taps the thumbnail, use `AVPlayerViewController` or a similar native iOS media player to play the video directly in the app, rather than navigating to a web view. This would provide a faster, more seamless experience and avoid the need to open the separate YouTube app. 