# Feature: Application Startup and Initialization

**Last Updated:** 2024-07-29

## 1. Summary

This document describes the application's startup sequence, from the OS-level launch to the presentation of the initial user interface. The process involves several configuration files and relies on programmatic UI setup within the `AppDelegate`. The sequence differs based on whether the user is currently logged in.

## 2. User-Facing Entry Points

This process is initiated automatically when the user launches the application. It can also be triggered by an external URL that uses one of the app's custom schemes (`awful://`, `awfulhttp://`, `awfulhttps://`).

## 3. Pre-Code Initialization (System Level)

Before any of our Swift code runs, iOS performs the following steps based on the `Info.plist`:

1.  **Loads Launch Screen:** The system displays the UI from `LaunchScreen.storyboard`.
2.  **Loads Application Code:** The compiled application code is loaded into memory.
3.  **Instantiates `UIApplication` and `AppDelegate`:** iOS creates the singleton `UIApplication` object and an instance of our custom `AppDelegate` class to act as its delegate.

## 4. Programmatic Initialization (`AppDelegate.swift`)

The `AppDelegate` then orchestrates the entire setup process in a specific order.

### `application(_:willFinishLaunchingWithOptions:)`

This method is called first and is responsible for setting up the foundational components.

1.  **Sets Static Instance:** A global static reference is set via `AppDelegate.instance = self`. This singleton-like pattern is used elsewhere in the app.
2.  **Registers Defaults:** `UserDefaults.standard.register(defaults: Theme.forumSpecificDefaults)` sets default values for theme-related settings. This ensures the app has valid theme settings on first launch.
3.  **Migrates Settings:** `SettingsMigration.migrate(.standard)` runs to handle any migration of `UserDefaults` from older versions of the app.
4.  **Initializes Data Store:** `dataStore = DataStore(...)` creates the Core Data stack in the Application Support directory.
5.  **Initializes Networking Client:** `ForumsClient.shared` is configured with the managed object context and the base URL. A `didRemotelyLogOut` closure is also provided.
6.  **Configures URL Cache:** The shared `URLCache` is configured with specific memory and disk capacities.
7.  **Creates Main Window:** A `UIWindow` is created with the screen's bounds.
8.  **Sets Initial Root View Controller:**
    - The app checks `ForumsClient.shared.isLoggedIn`.
    - **If Logged In:** The `rootViewControllerStack` is accessed, which lazily initializes the `UISplitViewController` containing the `RootTabBarController`. This is set as the window's `rootViewController`.
    - **If Not Logged In:** A `LoginViewController` is instantiated and set as the `rootViewController`.
9.  **Initializes Helper Controllers:** The `OpenCopiedURLController` is initialized to handle prompts for URLs found on the clipboard.
10. **Makes Window Visible:** `window?.makeKeyAndVisible()` displays the configured UI to the user.

### `application(_:didFinishLaunchingWithOptions:)`

This method is called immediately after the first, giving the app a chance to perform secondary setup tasks.

1.  **Post-Appearance Logic:** Calls `_rootViewControllerStack?.didAppear()` to handle UI adjustments after state restoration or initial appearance.
2.  **Configures Audio Session:** `ignoreSilentSwitchWhenPlayingEmbeddedVideo()` sets the `AVAudioSession` category to `.playback`, allowing embedded videos to play sound even when the device's silent switch is on.
3.  **Sets up Refreshers:** `AnnouncementListRefresher`, `PrivateMessageInboxRefresher`, and `PostsViewExternalStylesheetLoader` are initialized to handle background data fetching.
4.  **Sets up Notification Observers:** Subscribes to system notifications like `Theme.themeForForumDidChangeNotification` and `UIContentSizeCategory.didChangeNotification`.
5.  **Sets up Combine Subscribers:** Several Combine pipelines are established to react to changes in settings (e.g., `automaticDarkTheme`, `darkMode`) and update the UI accordingly.

## 5. Key Files & Code Components

- **`App/Resources/Info.plist`**: Defines startup configurations like the launch screen, custom URL schemes, and supported orientations. The absence of a `UIMainStoryboardFile` key indicates programmatic UI setup.
- **`App/Main/AppDelegate.swift`**: The main application entry point. It implements `UIApplicationDelegate` and handles the core setup.
- **`App/Main/RootViewControllerStack.swift`**: Responsible for creating and managing the main, logged-in user interface (`UISplitViewController`).
- **`App/View Controllers/RootTabBarController.swift`**: A custom `UITabBarController` subclass that contains the primary navigation tabs.
- **`App/View Controllers/LoginViewController.swift`**: The view controller for the login screen.

## 6. Legacy Code & Modernization Plan

- **Pain Points:**
    - The entire startup sequence is imperative and tightly coupled to the `AppDelegate`, making it difficult to test and reason about.
    - State is managed through a combination of singleton patterns (`ForumsClient`), `UserDefaults`, and instance properties on the `AppDelegate`, which makes the flow of data difficult to trace.
    - The `RootViewControllerStack` contains significant workaround code to handle layout issues on older iOS versions.

- **Proposed Changes:**
    - **Adopt SwiftUI App Life Cycle:** Replace the `AppDelegate` with a SwiftUI `App` struct. The `body` of the `Scene` would be a `WindowGroup`.
    - **Centralize State Management:** Use SwiftUI environment objects (`@EnvironmentObject`) or a dedicated state container to manage application-wide state like authentication status and theme settings.
    - **Declarative Root View:** The root view within the `WindowGroup` would be a SwiftUI view. It would observe the authentication state and conditionally display either a new SwiftUI `LoginView` or the main `NavigationSplitView` containing a `TabView`.
    - **Configuration in Initializers:** Component setup (like the networking client) can be moved into the initializers of custom `ObservableObject`s or handled via `.onAppear` modifiers in SwiftUI views, removing them from a monolithic `AppDelegate` method.
    - **Handle URL Schemes with SwiftUI:** Use the `.onOpenURL` modifier on a root view to handle incoming URLs from custom schemes. 
