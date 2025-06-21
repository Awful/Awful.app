# Feature: Posts View

**Last Updated:** 2024-07-29

## 1. Summary

The Posts View is the core feature for reading threads. It's a complex system that renders a full page of forum posts into a `WKWebView`, leveraging a templating engine for HTML generation and a JavaScript bridge for interactivity. This approach allows for rich, CSS-styled content but introduces significant complexity compared to a native SwiftUI view.

## 2. Architecture and Data Flow

The process of displaying a page of posts involves several distinct stages, orchestrated by `PostsPageViewController`.

### 2.1. Data Fetching and Preparation

1.  **Trigger:** Loading is initiated by `PostsPageViewController.loadPage(...)`.
2.  **Network Request:** It fetches raw post data from the `ForumsClient`.
3.  **Context Assembly:** The view controller assembles a context dictionary. This dictionary contains:
    *   The array of `Post` objects to be rendered.
    *   The current `Theme`, which provides the main stylesheet.
    *   The external stylesheet (from `awfulapp.com`).
    *   User settings that affect rendering (e.g., `showAvatars`, `fontScale`).
    *   The thread ID and forum ID for CSS scoping.

### 2.2. HTML Generation (Stencil)

The app uses the **Stencil** templating engine to generate the HTML for the web view.

1.  **`StencilEnvironment.swift`**: This file configures a shared `Stencil.Environment`. It sets up a `BundleResourceLoader` to find templates in the app's bundle and registers several custom filters (e.g., `formatPostDate`, `htmlEscape`) and tags (e.g., `fontScaleStyle`) for use in the templates.
2.  **Templates**:
    *   **`Post.html.stencil`**: This is the template for a *single* post. It defines the HTML structure for the author's header, avatar, post body, and footer.
    *   **`PostsView.html.stencil`**: This is the *master* template for a full page. It sets up the main `<html>` and `<body>` tags and includes the necessary CSS and JavaScript. Crucially, it loops through the array of post objects from the context and includes `Post.html.stencil` for each one.
3.  **Rendering**: `PostsPageViewController` calls `StencilEnvironment.shared.renderTemplate(.postsView, context: ...)` to produce the final HTML string.

### 2.3. Rendering and Display (WKWebView)

1.  **`PostsPageView.swift`**: This is the main `UIView` for the feature. It contains a `RenderView`, which is a custom `WKWebView` subclass.
2.  **Loading HTML**: The fully rendered HTML string is loaded into the `RenderView` using `renderView.loadHTMLString(...)`.
3.  **Styling**:
    *   **Inline Styles**: The current theme's stylesheet (e.g., from the `postsViewCSS` theme key) is injected directly into a `<style>` tag in `PostsView.html.stencil`.
    *   **External Stylesheet**: The app also fetches a remote stylesheet (defined by `AwfulPostsViewExternalStylesheetURL` in `Info.plist`) and injects it. This allows for global style updates without shipping a new app version.

### 2.4. Interactivity (JavaScript Bridge)

Communication from the web view back to the native app is handled via a JavaScript bridge.

1.  **`WKScriptMessageHandler`**: `PostsPageViewController` conforms to `WKScriptMessageHandler` and registers itself to listen for various messages from the JavaScript context.
2.  **JavaScript (`RenderView.js`)**: A corresponding JavaScript file (`RenderView.js`) is injected into the web view. It adds event listeners to the rendered HTML. When a user taps an action button, for example, the JavaScript calls `window.webkit.messageHandlers.awful.postMessage(...)` with a JSON payload describing the action.
3.  **Action Handling**: `PostsPageViewController` receives the message in its `userContentController(_:didReceive:)` method, decodes the action, and presents the appropriate native UI (e.g., a context menu for post actions, a profile view, etc.).

#### Client-Side Content Embedding
The JavaScript in `RenderView.js` is also responsible for dynamically embedding rich content after the initial HTML has loaded. For features like embedded tweets, the JavaScript finds tweet URLs in the rendered HTML and uses a JSONP request to fetch the embeddable HTML from Twitter's oEmbed API. It then replaces the link with the rich content directly in the DOM. This client-side enhancement allows for features that the server-side forum software does not provide.

## 4. Key Files & Code Components

-   **View Controller**: `App/View Controllers/Posts/PostsPageViewController.swift`
-   **Views**: `App/Views/PostsPageView.swift`, `App/Views/RenderView.swift` (the `WKWebView` subclass)
-   **Templates**: `App/Templates/PostsView.html.stencil`, `App/Templates/Post.html.stencil`
-   **Templating Engine**: `App/Misc/StencilEnvironment.swift` (configures the Stencil library)
-   **JavaScript Bridge**: `App/Resources/RenderView.js`
-   **Stylesheet Loader**: `App/Posts/PostsViewExternalStylesheetLoader.swift`

## 5. Legacy Code & Modernization Plan

-   **Pain Points:**
    -   The entire architecture is incredibly complex, spanning Swift, HTML, CSS, and JavaScript. Debugging is difficult.
    -   Rendering performance is tied to `WKWebView`, which can be slower and more memory-intensive than native views.
    -   The reliance on a JavaScript bridge for all interactivity is brittle and adds a significant layer of indirection.
    -   Layout is defined in HTML/CSS, completely disconnected from the native layout system, making it difficult to create dynamic, responsive layouts that feel at home on iOS.

-   **Proposed Changes (SwiftUI):**
    -   **Native Rendering**: The entire `WKWebView`-based rendering pipeline should be deprecated. Instead, create a native SwiftUI view for displaying posts.
    -   **`List` or `ScrollView`**: A SwiftUI `List` would be the most efficient way to render a page of posts, as it provides view recycling for free.
    -   **`PostView`**: Create a dedicated `PostView` in SwiftUI to represent a single post. This view would be responsible for laying out the avatar, username, post body, and action buttons using standard SwiftUI components (`VStack`, `HStack`, `Text`, `Button`, etc.).
    -   **Attributed Strings for Post Body**: The HTML post body (`htmlContents`) can be converted into a `NSAttributedString` and displayed in SwiftUI using a `UILabel` wrapped in `UIViewRepresentable` or, in iOS 15+, directly with `Text(AttributedString)`. This retains rich text formatting without the overhead of a web view.
    -   **Direct Actions**: The post action button would be a native SwiftUI `Button` that directly calls a method on its view model, completely eliminating the JavaScript bridge.
    -   **Theming**: All styling would be applied directly in SwiftUI using the `Environment`-based theming system proposed in `Theming.md`. Colors, fonts, and spacing would be pulled from the `theme` object in the environment. This centralizes styling and makes it fully reactive. 