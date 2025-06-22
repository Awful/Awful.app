# Navigation and View Hierarchy

**Last Updated:** 2024-07-30

## 1. Summary

The application's navigation is built on a highly customized UIKit stack, primarily designed for a two-column layout on iPad and adaptable for iPhone. The root of the logged-in interface is a `UISplitViewController` that houses a `UITabBarController` in its primary (master) pane and a `UINavigationController` in its secondary (detail) pane.

This architecture is heavily modified with custom subclasses to implement application-specific features like theming, unique navigation gestures (e.g., "un-popping"), and, most critically, to apply workarounds for layout bugs and behavioral inconsistencies found in older versions of iOS (specifically iOS 11 and 12).

## 2. User-Facing Entry Points

A user navigates through the app primarily by:

- Tapping tabs in the main `UITabBarController` (Forums, Bookmarks, Messages, etc.).
- Tapping on items within a list (e.g., selecting a forum or a thread), which typically pushes a new view controller onto the detail pane's navigation stack.
- Using the back button within a navigation controller.
- On iPhone, using a custom edge-swipe gesture to "un-pop" a previously popped view controller.

## 3. Key Files & Code Components

- **`App/Main/RootViewControllerStack.swift`**: The orchestrator for the logged-in UI. It programmatically initializes, configures, and wires together the `UISplitViewController`, `UITabBarController`, and their initial child view controllers.

- **`App/Main/AwfulSplitViewController.swift`**: A thin subclass of `UISplitViewController` that mainly serves to forward status bar style questions and view transition events to its delegate.

- **`App/View Controllers/RootTabBarController.swift`**: A `UITabBarController` subclass that, along with its custom `RootTabBar` class, contains significant workarounds to fix layout issues on iOS 11 and 12, particularly concerning how the tab bar lays out its items within the constrained width of a split view's primary pane. It's loaded from a Storyboard (`RootTabBarController.storyboard`) primarily as a means to use its custom `UITabBar` subclass.

- **`App/Navigation/NavigationController.swift`**: A custom `UINavigationController` subclass used throughout the app. It adds several key features:
    - **Theming**: Applies custom colors and styles to its `NavigationBar` and `Toolbar`.
    - **Custom Toolbar/Navbar**: Uses `NavigationBar.swift` and `Toolbar.swift`.
    - **"Un-popping"**: Implements a right-edge-swipe gesture on iPhone to restore a previously popped view controller.
    - **iOS 15 Fixes**: Contains specific code to handle changes in navigation bar appearance introduced in iOS 15.

- **`App/Navigation/Toolbar.swift`**: A simple `UIToolbar` subclass that adds a custom top border and sets a default tint color.

## 4. How It Works

The navigation hierarchy is established in `RootViewControllerStack`.

1.  An `AwfulSplitViewController` is created to serve as the root. To work around an iOS bug, this split view is actually embedded as a child of a generic `PassthroughViewController`.
2.  A `RootTabBarController` is instantiated from a storyboard. Its view controllers are set to be instances of `NavigationController`, each containing one of the main app sections (Forums, Bookmarks, etc.). This tab bar controller becomes the primary view controller of the split view.
3.  An empty `NavigationController` is created and set as the secondary (or "detail") view controller of the split view.
4.  When the user selects an item (like a thread), the corresponding view controller is pushed onto this detail navigation controller's stack.
5.  When the split view collapses (e.g., on an iPhone), the view controllers from the detail navigation stack are moved onto the primary navigation stack. The code for this contains several workarounds to ensure the toolbar items remain visible and interactive.

The entire system relies on a significant amount of custom code for state restoration, theming, and managing the visibility of the primary pane in the split view, with many comments in the code pointing out the "ugly" but necessary nature of these fixes.

## 5. Legacy Code & Modernization Plan

The current navigation system is a product of its time, built to support older iOS versions and work around their specific bugs. This makes it fragile and difficult to maintain, especially as new OS versions are released. The user has noted that it is already failing with the toolbar/tabbar changes.

### Pain Points

-   **Brittle OS Version Workarounds**: The code is littered with fixes targeted at specific iOS versions (e.g., `kindaFixReallyAnnoyingSplitViewHideSidebarInLandscapeBehavior`, the `RootTabBar` trait collection override for iOS 11, and size calculations for iOS 12). These are technical debt that can (and do) break with new OS updates.
-   **Imperative & Complex**: The entire view hierarchy is assembled imperatively. State, such as which tab is selected or the contents of the navigation stacks, is managed through direct manipulation of UIKit objects. This makes the flow of control hard to follow.
-   **Complex State Restoration**: The app uses the legacy `UIStateRestoring` protocol, with manual logic in `RootViewControllerStack` to find and restore view controllers based on identifier paths. This is complex and error-prone.
-   **Theming**: Theming is handled by `Themeable` protocols and `themeDidChange()` methods, which require each component to manually update its own appearance.
-   **Abuse of Storyboards**: `RootTabBarController.storyboard` exists solely to allow the use of a custom `UITabBar` subclass, a known workaround for a limitation in UIKit's programmatic APIs.

### Proposed Changes

The clear path forward is to migrate the entire navigation and root view structure to SwiftUI.

-   **Adopt `NavigationSplitView` and `TabView`**:
    -   Replace `AwfulSplitViewController` with a SwiftUI `NavigationSplitView`. This modern API is designed for this exact two-column layout and is maintained by Apple.
    -   Replace `RootTabBarController` with a SwiftUI `TabView`. The tabs can be defined declaratively.
    -   This would eliminate the need for `RootViewControllerStack`, as the view hierarchy would be declared in the body of a SwiftUI `View`.

-   **Declarative Navigation**:
    -   Use `NavigationStack` within the detail pane of the `NavigationSplitView`. Navigation can be driven by state (e.g., `@State` or a navigation-specific `ObservableObject`) rather than by imperative calls to `pushViewController`.

-   **Simplify State Management**:
    -   SwiftUI's built-in state management (`@State`, `@Binding`, `@EnvironmentObject`) would replace the manual state restoration code. The state of the UI would be a direct function of the application's data model.

-   **Modernize Theming**:
    -   Theming can be achieved more elegantly and declaratively in SwiftUI using `.environment()` and custom `ViewModifier`s, removing the need for `themeDidChange()` calls.

-   **Remove Legacy Code**:
    -   This migration would allow for the complete removal of the iOS 11/12/15-specific workarounds, the custom "un-popping" gesture (which could be re-evaluated for necessity), the storyboard, and the complex delegate and state restoration logic. The result would be a smaller, more modern, more maintainable, and more stable codebase. 