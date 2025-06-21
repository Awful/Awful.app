# Context Menus and Actions

The application uses two distinct systems for presenting context menus, reflecting the app's age and its ongoing modernization. A legacy system based on `UIMenuController` is used for the text composer, while a modern system using `UIMenu` is used for the posts view and other areas.

## 1. Legacy System: `UIMenuController` in the Text Composer

The context menu that appears when selecting text in the post composition view (`ComposeTextView`) is powered by the classic, singleton-based `UIMenuController`.

-   **`CompositionMenuTree.swift`**: This class is the brain of the composer's menu system. It directly manipulates `UIMenuController.shared` to set and update the menu items that are displayed.
-   **`PSMenuItem`**: To overcome the limitations of the old selector-based `UIMenuItem`, the project uses a vendored library called `PSMenuItem`. This is a subclass of `UIMenuItem` that allows for modern, block-based actions, simplifying the code significantly.
-   **Manual Lifecycle**: `CompositionMenuTree` is responsible for the entire lifecycle of the menu. It uses `NotificationCenter` to observe when the text view begins and ends editing, and when the menu is hidden, so it can show, hide, and update the menu items manually.
-   **Fake Submenus**: It simulates hierarchical menus (e.g., an "Insert..." item that reveals more options) by replacing the `menuItems` array on the `UIMenuController` and re-presenting the menu when an item is tapped.

## 2. Modern System: `UIMenu` in the Posts View

A much more modern and complex system is used to present native context menus when a user taps on elements *within the `WKWebView`* that displays posts. This allows native menus to be triggered from JavaScript events.

### The JavaScript-to-Native Bridge

1.  **JavaScript Event Listener**: The JavaScript running within the posts view (`RenderView.js`) adds event listeners to post action buttons and author headers.
2.  **`postMessage` Bridge**: When a user taps one of these elements, the JavaScript captures the event. It then calls `window.webkit.messageHandlers.DidTapPostActionButton.postMessage(...)`, sending a payload containing the post ID, user ID, and the frame of the tapped element (as a stringified `CGRect`) back to the native Swift code.
3.  **`WKScriptMessageHandler`**: `PostsPageViewController` acts as a `WKScriptMessageHandler` (via its `RenderViewDelegate` conformance). It receives the message from JavaScript and parses the payload to identify which post/user was tapped and where on the screen the tap occurred.

### The "Hidden Button" Trick

Presenting a `UIMenu` requires a source view and rect. To solve this problem when the source is a JavaScript event, the app uses a clever workaround:

1.  **`HiddenMenuButton`**: `PostsPageViewController` contains an invisible `UIButton` subclass called `HiddenMenuButton`.
2.  **`showsMenuAsPrimaryAction`**: This button is configured with `showsMenuAsPrimaryAction = true`. This is a key property that causes the button to display its assigned `UIMenu` on a standard tap, rather than requiring a long press.
3.  **Menu Triggering**: When the view controller receives the message from JavaScript:
    a. It builds the appropriate `UIMenu` with all the relevant actions for the selected post or user.
    b. It moves the invisible `HiddenMenuButton` to the exact `CGRect` that was sent from JavaScript.
    c. It programmatically assigns the newly created menu to the button.
    d. Finally, it programmatically fakes a "touch down" event on the hidden button.
4.  **Menu Presentation**: UIKit's responder chain sees a tap on a button that is configured to show a menu as its primary action, and it dutifully presents the `UIMenu` at the button's (and thus the user's tap) location.

This elaborate system seamlessly bridges the web content with the native UI, providing a high-fidelity user experience.

## Modernization Plan

-   **Legacy Menu**: The `CompositionMenuTree` and its use of `UIMenuController` should be replaced entirely. A modernized text composer, likely built with SwiftUI's `TextEditor`, would use the standard `.contextMenu` view modifier to attach a modern `UIMenu` far more simply. The `PSMenuItem` dependency could be removed.
-   **Modern Menu**: The "Hidden Button" trick, while very clever, is a workaround for the limitations of `WKWebView`. A fully native SwiftUI posts view would eliminate the need for this entire JavaScript bridge. Each element in the view (the author header, the action button) would be a native `Button` or other control, and a context menu could be attached directly to it with the `.contextMenu` modifier, reducing hundreds of lines of complex bridging code to a few lines of declarative SwiftUI. 