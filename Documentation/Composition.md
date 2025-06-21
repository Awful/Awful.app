# Feature: Text Composition

**Last Updated:** 2024-07-29

## 1. Summary

The text composition system is a highly reusable and somewhat complex feature built around a generic, abstract view controller that is specialized for different tasks like creating new threads, posting replies, and sending private messages. It includes built-in functionality for handling image uploads, previewing content, and managing drafts.

## 2. Architecture and Data Flow

The architecture follows a pattern of a generic base class being configured and specialized by other controllers or wrapper classes.

### 2.1. Core Component: `ComposeTextViewController`

-   **Location:** `App/Composition/ComposeTextViewController.swift`
-   **Role:** This is an abstract base class that provides the fundamental UI and logic for text composition.
-   **Key Features:**
    -   A main `UITextView` for the body.
    -   A `customView` property, which is a `UIView` that can be inserted at the top to hold additional input fields (like a subject line).
    -   A context menu system, managed by `CompositionMenuTree`, that uses the legacy `UIMenuController` to provide actions like "Insert Image".
    -   Automatic handling of keyboard appearance to prevent it from covering the text input area.
    -   An `uploadImages(...)` method that's called before submission, which finds image attachments, uploads them to Imgur, and replaces them with the appropriate BBcode tags.
    -   Abstract methods like `submit(...)` and properties like `submissionInProgressTitle` that **must** be implemented by a subclass.
    -   A delegate protocol (`ComposeTextViewControllerDelegate`) to report completion or cancellation.

### 2.2. Specialization for New Threads: `ThreadComposeViewController`

-   **Location:** `App/View Controllers/Threads/ThreadComposeViewController.swift`
-   **Role:** Subclasses `ComposeTextViewController` to add the specific functionality needed to create a new thread.
-   **Specializations:**
    -   **Adds Custom Fields:** Inserts a `NewThreadFieldView` into the `customView` property to add a **Subject** field and a **Thread Tag** button.
    -   **Fetches Thread Tags:** Asynchronously fetches the available thread tags for the forum and presents a `ThreadTagPickerViewController`.
    -   **Implements a Preview Step:** Overrides `shouldSubmit(...)` to push a `ThreadPreviewViewController` instead of submitting directly. The actual submission is triggered from the preview screen.
    -   **Implements Submission:** Overrides `submit(...)` to call `ForumsClient.shared.postThread(...)` with the subject, tags, and body text.

### 2.3. Specialization for Private Messages: `MessageComposeViewController`

-   **Location:** `App/View Controllers/Messages/MessageComposeViewController.swift`
-   **Role:** Subclasses `ComposeTextViewController` for composing private messages.
-   **Specializations:**
    -   **Adds Custom Fields:** Inserts a `NewPrivateMessageFieldView` to add **To** and **Subject** fields.
    -   **Implements Submission:** Overrides `submit(...)` to call `ForumsClient.shared.sendPrivateMessage(...)`.
    -   Handles different contexts, such as a new message, a reply, or a forward, by pre-populating the "To" and "Subject" fields accordingly.

### 2.4. Specialization for Replies: `ReplyWorkspace` + `CompositionViewController`

This is the most complex flow. It uses a state-management object to wrap a *different* composition view controller.

1.  **`ReplyWorkspace.swift`**: This is a non-UI, state-management class. When a user wants to reply, a `ReplyWorkspace` is created for that thread.
2.  **`CompositionViewController.swift`**: This is another composition view controller. The `ReplyWorkspace` creates an instance of this view controller.
3.  **Configuration**: The `ReplyWorkspace` is responsible for configuring the `CompositionViewController`. It sets the initial text (e.g., from a quoted post), sets the navigation bar buttons, and points their actions back to itself.
4.  **Presentation**: The `PostsPageViewController` presents the `viewController` property of the `ReplyWorkspace`, which is the fully-configured `CompositionViewController`.
5.  **Submission**: Actions like "Post" or "Preview" are handled by the `ReplyWorkspace`, which then calls the appropriate `ForumsClient` method (e.g., `reply(...)`).

## 3. Key Files & Code Components

-   **Abstract Base Class:** `App/Composition/ComposeTextViewController.swift`
-   **New Thread Implementation:** `App/View Controllers/Threads/ThreadComposeViewController.swift`
-   **Private Message Implementation:** `App/View Controllers/Messages/MessageComposeViewController.swift`
-   **Reply Implementation Wrapper:** `App/Posts/ReplyWorkspace.swift`
-   **Generic Composition UI (for Replies):** `App/Composition/CompositionViewController.swift`
-   **Context Menu Logic:** `App/Composition/CompositionMenuTree.swift`
-   **Custom Input Views:** `NewThreadFieldView.swift`, `NewPrivateMessageFieldView.swift`
-   **Image Uploading:** The `ImgurAnonymousAPI` module and `ComposeTextViewController+Imgur.swift`.

## 4. Legacy Code & Modernization Plan

-   **Pain Points:**
    -   The architecture is confusing, especially for replies. The existence of `ComposeTextViewController`, `CompositionViewController`, and the `ReplyWorkspace` wrapper makes the flow hard to follow.
    -   Heavy use of inheritance and subclassing makes behavior difficult to predict without examining multiple files.
    -   State is managedimperatively through properties and delegates.
    -   The UI is built with UIKit and relies on manual layout and keyboard handling.

-   **Proposed Changes (SwiftUI):**
    -   **Unify Composition Views:** Create a single, powerful `ComposeView` in SwiftUI.
    -   **State-Driven Configuration:** Instead of subclassing, the `ComposeView`'s configuration would be driven by its `init` parameters or a view model. For example:
        ```swift
        // For a new thread
        ComposeView(mode: .newThread(forum: currentForum))

        // For a reply
        ComposeView(mode: .reply(thread: currentThread, quoting: selectedPost))
        ```
    -   **`@ViewBuilder` for Custom Fields:** The `customView` slot could be replaced with a `@ViewBuilder` closure, allowing the parent view to inject the necessary fields declaratively.
        ```swift
        ComposeView(mode: .newThread(forum: forum)) {
            SubjectField(text: $subject)
            ThreadTagPicker(selection: $tag)
        }
        ```
    -   **Environment for Theming:** The view would pull all its styling from the `Environment`, as described in `Theming.md`.
    -   **Native Keyboard Handling:** SwiftUI's default keyboard avoidance behavior, combined with `FocusState`, would replace the manual keyboard notification handling.
    -   **`async/await` for Submission:** The submission process would become a simple `async` function on the view model, which could handle image uploads and the final submission in a clear, linear sequence. This removes the need for complex completion handlers and state management. 