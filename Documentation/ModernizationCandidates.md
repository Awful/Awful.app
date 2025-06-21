# Feature: Modernization Candidates

**Last Updated:** 2024-07-29

## 1. Summary

This document identifies key files, architectural patterns, and technologies in the Awful app that are considered legacy by modern iOS development standards. For each candidate, it provides a rationale for its replacement and describes the modern SwiftUI-based alternative. This serves as a high-level roadmap for refactoring the application.

---

## 2. Application Lifecycle & Entry Point

### Candidate: `AppDelegate.swift`

-   **Role:** The central hub for the application's lifecycle in the `UIApplicationDelegate` model. It handles app launch, backgrounding, termination, push notifications, and setting up the initial `UIWindow` and root view controller.
-   **Why it's Legacy:** The SwiftUI App Life Cycle, introduced in iOS 14, replaces the `AppDelegate` and `SceneDelegate` system with a more declarative, streamlined approach. The `AppDelegate` combines too many responsibilities, making it a complex and hard-to-maintain singleton.
-   **Modern Replacement:**
    -   An **`@main` struct conforming to the `App` protocol** becomes the new entry point.
    -   A **`WindowGroup`** within the `App`'s `body` defines the root scene of the application.
    -   App lifecycle events are handled by observing the **`@Environment(\.scenePhase)`** variable within a view or by using `onChange(of:)` on the scene itself.
    -   For features that still require an `AppDelegate` (like some push notification setups), a minimal one can be attached to the SwiftUI `App` using the **`@UIApplicationDelegateAdaptor`** property wrapper, but its role is significantly reduced.

---

## 3. UI and View Hierarchy

### Candidate: Storyboards (`.storyboard`)

-   **Role:** Used for visually designing the UI and the flow between view controllers. This project uses `LaunchScreen.storyboard` and `RootTabBarController.storyboard`.
-   **Why it's Legacy:** Storyboards can become difficult to manage in large projects, are prone to source control conflicts (as they are large XML files), and represent a complete separation of layout and logic. SwiftUI's declarative, code-based approach is now the standard for new app development.
-   **Modern Replacement:**
    -   **SwiftUI Views:** All UI is built declaratively in code using SwiftUI views like `VStack`, `List`, `Text`, etc.
    -   **Launch Screen Settings:** `LaunchScreen.storyboard` is replaced by the "Launch Screen" section in the Xcode target's settings, which can be configured with a simple image asset and background color.

### Candidate: Programmatic UIKit Containers (`RootViewControllerStack.swift`)

-   **Role:** This class manually creates and configures complex UIKit view controller hierarchies, such as the `AwfulSplitViewController` that holds the main `UITabBarController`.
-   **Why it's Legacy:** This imperative approach to UI construction is verbose, hard to reason about, and requires manual state management.
-   **Modern Replacement:**
    -   **SwiftUI Container Views:** The entire stack can be replaced with native SwiftUI containers.
    -   `UISplitViewController` -> `NavigationSplitView`
    -   `UITabBarController` -> `TabView`
    -   `UINavigationController` -> `NavigationStack`

---

## 4. Feature Implementation Patterns

### Candidate: `WKWebView`-based Rendering (`PostsView.md`)

-   **Role:** The posts view renders an entire page of content by generating a large HTML string (via the Stencil templating engine) and loading it into a `WKWebView`. Interactivity is handled via a fragile JavaScript bridge.
-   **Why it's Legacy:** This is an extremely complex and indirect way to display what is essentially a list of content. It's inefficient, hard to debug, and feels non-native.
-   **Modern Replacement:**
    -   A **SwiftUI `List`** is the ideal replacement, providing native performance and automatic view recycling.
    -   Each post would be its own **SwiftUI `View` struct**.
    -   HTML content in the post body can be rendered into a `NSAttributedString` and displayed in a native `Text` view, preserving rich formatting without the overhead of a web view.

### Candidate: Imperative Theming (`Theming.md`)

-   **Role:** The app uses a `Themeable` protocol and a `themeDidChange()` method that is called on all views when the theme changes. Each view is responsible for imperatively updating its own appearance.
-   **Why it's Legacy:** This pattern is boilerplate-heavy and not reactive. It requires manual traversal of the view hierarchy.
-   **Modern Replacement:**
    -   **SwiftUI Environment:** The current theme object is injected into the SwiftUI `Environment`. Views declaratively read styling information from the environment. When the theme object changes in the environment, all dependent views automatically and efficiently update themselves.

---

## 5. Persistence and Session

### Candidate: Manual Core Data Stack (`DataStore.swift`)

-   **Role:** `DataStore.swift` manually initializes the `NSManagedObjectModel`, `NSPersistentStoreCoordinator`, and `NSManagedObjectContext`.
-   **Why it's Legacy:** This pattern was necessary before iOS 10. It is verbose and error-prone.
-   **Modern Replacement:**
    -   **`NSPersistentContainer`**: The modern, standard way to set up a Core Data stack. It handles the creation of the stack with a single initialization and provides helper methods for background contexts and other common tasks.

### Candidate: `HTTPCookieStorage` for Session State

-   **Role:** The app's logged-in state is determined solely by the presence of a `bbuserid` cookie in the global `HTTPCookieStorage`.
-   **Why it's Legacy:** This tightly couples the application's state logic to a side effect of the networking layer. It's not a robust or observable source of truth for the user's session.
-   **Modern Replacement:**
    -   **A dedicated `SessionManager` `ObservableObject`**: This object would manage the user's authentication state. Upon login, it would securely store session tokens or user identifiers in the **Keychain** and publish its state (e.g., `.loggedIn` or `.loggedOut`). The rest of the app would observe this object (likely injected via the environment) to react to authentication changes. 