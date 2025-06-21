# Networking Layer

All network communication with the Something Awful forums is centralized in a single singleton class: `ForumsClient`. This class acts as a comprehensive API client, providing a high-level, asynchronous, and Swift-native interface over the forums' legacy, form-based web interface.

## Core Fetch Method

The foundation of the entire networking layer is a private `async` method within `ForumsClient`:

`private func fetch(...) async throws -> (Data, URLResponse)`

This method is the workhorse responsible for the low-level details of every network request:

-   **`URLSession`**: It uses a shared `URLSession` instance to execute all requests.
-   **Request Building**: It dynamically builds a `URLRequest` for either a `GET` or `POST` operation.
-   **Parameter Encoding**: It correctly encodes all request parameters using the `windowsCP1252` character set, which is required by the Something Awful forums' backend. For `POST` requests, it properly formats the body as `multipart/form-data`.
-   **Concurrency**: It uses Swift's modern `async/await` syntax to perform the network call without blocking the calling thread.
-   **Error Handling**: It wraps the network call in a `do/catch` block, propagating any `URLError`s up to the caller.
-   **Session Management**: It transparently checks if a network response has invalidated the user's session (e.g., by removing the session cookie) and can post a notification to trigger a global logout.

## Public API Surface

All other public methods in `ForumsClient` are built on top of the core `fetch` method. They provide a semantic API that hides the implementation details of specific endpoints and parameters. These public methods can be grouped by functionality:

### Session Management
-   `logIn(username:password:)`
-   `logOut()`

### Forum & Thread Lists
-   `taxonomizeForums()`
-   `listThreads(in:tagged:page:)`
-   `listBookmarkedThreads(page:)`
-   `searchThreads(query:forums:sort:order:)`
-   `getAnnouncements()`

### Thread & Post Actions
-   `getPosts(in:page:ofUser:)`
-   `getThreadInfo(_:)`
-   `markThreadRead(_:)`
-   `markPostsRead(upTo:in:)`
-   `addBookmark(_:)`
-   `removeBookmark(_:)`
-   `vote(on:rating:)`

### Post Creation & Editing
-   `reply(to:text:)`
-   `newThread(in:subject:secondaryTag:text:)`
-   `getReplyInfo(for:)`
-   `getPostInfo(for:)`
-   `edit(post:text:)`

### Private Messages
-   `listPrivateMessages(inbox:)`
-   `getMessage(_:)`
-   `sendPrivateMessage(to:subject:body:forwarding:)`
-   `deleteMessage(_:)`

### User & Profile Actions
-   `getUserProfile(for:)`
-   `getRapSheet(for:)`
-   `ignore(user:)`
-   `unignore(user:)`

Each of these methods is an `async` function that internally calls the `fetch` method, then either decodes the response as JSON or parses it as HTML to extract the required data before returning it to the caller.

## Modernization Plan

The networking layer is already in excellent shape. It's centralized, uses modern Swift concurrency, and provides a clean, high-level API.

-   **No Major Changes Needed**: There are no pressing architectural changes required for this component. It effectively serves the needs of the entire application.
-   **Decoupling Scrapers**: As mentioned in the Scraping documentation, the only significant improvement would be to move the *parsing* logic (the code that uses `HTMLReader`) out of `ForumsClient` and into the `AwfulScraping` package. This would leave `ForumsClient` with the sole responsibility of networking, further solidifying its role as a pure API client.
-   **Encoding Modernization**: The reliance on `windowsCP1252` is a legacy requirement. While necessary for some form submissions, a review should be conducted to see which endpoints can use standard `URLQueryItem`s with modern, URL-safe string encoding. This would reduce complexity and a potential source of bugs. 