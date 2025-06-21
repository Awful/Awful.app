# Miscellaneous & Technical Debt

This document covers various topics that don't fit into a single feature category, as well as a summary of technical debt discovered through `TODO` and `FIXME` comments in the codebase.

## Vendored Dependencies

The `Vendor/` directory contains several third-party libraries that are manually included in the project. Most of these are older, Objective-C libraries that are excellent candidates for replacement with modern, Swift-based alternatives or system APIs.

-   **`MRProgress`**: An Objective-C library for displaying progress HUDs and other indicators.
    -   **Modernization**: This can be replaced entirely by native SwiftUI views. Simple loading spinners can be implemented with `ProgressView`, and custom, animated HUDs can be built as custom `View`s. For UIKit contexts, `UIActivityIndicatorView` is the standard system component.

-   **`PSMenuItem`**: A small, vendored Objective-C library that allows `UIMenuItem` (part of the legacy `UIMenuController` system) to be created with block-based handlers instead of selector targets. This is used for the text composition context menu. This can be completely removed when the composition UI is updated to use modern `UIMenu`s.

-   **`PullToRefresh`**: A simple, vendored pull-to-refresh implementation. The entire library can be deleted and replaced with the native `UIRefreshControl` or the SwiftUI `.refreshable` modifier.

-   **`ARChromeActivity` & `TUSafariActivity`**: Custom `UIActivity` subclasses for adding "Open in Chrome" and "Open in Safari" actions to `UIActivityViewController` (the share sheet).
    -   **Modernization**: This is a valid use of `UIActivity` and is still the correct way to add custom actions to a share sheet. However, the code could be updated to Swift and potentially simplified.

## Summary of Technical Debt

A search for `TODO` and `FIXME` comments throughout the codebase reveals several areas for improvement.

### Architectural Issues
-   **Separation of Concerns**: Several comments note that responsibilities are in the wrong place, such as view controllers handling data transformation that should be in a view model, or models performing parsing that should be in the scraping layer. This aligns with the general modernization goal of moving towards a cleaner MVVM-style architecture.
-   **Hardcoded Theme Logic**: In `AwfulSettings`, `TODO`s indicate that theme migration logic is hardcoded and should be using the `AwfulTheming` module directly to be more robust.

### `UIWebView` to `WKWebView` Remnants
-   A recurring `TODO` in `PostsPageViewController` and `AnnouncementViewController` highlights an unsolved problem from the `UIWebView` to `WKWebView` migration. The code needs a reliable way to find the position of an HTML element after an event like device rotation, which is more difficult with `WKWebView`'s asynchronous JavaScript evaluation. A robust solution for this would likely involve a more modern JavaScript bridging approach.

### Missing Features & UX Polish
-   **Error Handling**: A common comment is `// TODO: show error nicer`. This indicates a project-wide need to replace basic `UIAlertController` error messages with a more polished, less intrusive system for notifying the user of network or parsing failures.
-   **Missing Gestures**: Comments in `RootViewControllerStack` and `UnpoppingViewHandler` mention incomplete or missing custom navigation gestures, suggesting that some of the app's fluid navigation was lost in previous refactors and could be restored.
-   **Imgur Replacement**: A `TODO` in `CompositionMenuTree` mentions that the Imgur upload items are disabled because Imgur now deletes anonymous uploads. The entire image upload workflow needs to be re-thought and pointed at a different image hosting service.

### Known Issues (`FIXME`/`TODO`)

A search for `FIXME` and `TODO` comments in the codebase reveals several known areas of technical debt:

- **Logic in View Controllers**: There are several instances of `FIXME` where networking or data manipulation logic is performed directly within a view controller, rather than being properly layered in a view model or data service.
- **`UIWebView` Remnants**: The codebase contains leftover code and comments related to the migration from the old `UIWebView` to `WKWebView`, some of which may no longer be relevant.
- **Inconsistent Error Handling**: Error handling is often done with a simple `present(alert, ...)` call, with no centralized system for logging or presenting errors in a consistent way.

### Error Handling

The application's current approach to error handling is inconsistent. Most errors, particularly those from the `ForumsClient`, are propagated up to the calling view controller. The view controller is then responsible for catching the error and presenting a `UIAlertController` to the user.

- **Pain Points**:
    - There is no centralized error logging or tracking system.
    - The user experience is inconsistent, as each view controller might present errors differently.
    - Errors that occur in background processes (like the refreshers) are often silently ignored.

- **Modernization Plan**:
    - **Centralized Error Service**: A dedicated service could be created to handle all errors. This service could be responsible for logging errors to a remote service (like Sentry or Datadog), and for determining how an error should be presented to the user.
    - **User-Facing Error Views**: Instead of `UIAlertController`, a less intrusive, modern error presentation could be used, such as a toast, a banner at the top of the screen, or an inline error state within the UI. This could be implemented as a SwiftUI view modifier that observes an error state object. 