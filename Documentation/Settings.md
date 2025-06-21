# Feature: Settings

**Last Updated:** 2024-07-29

## 1. Summary

The settings feature allows users to customize a wide range of application behaviors, from appearance and theming to feature toggles and account information. Uniquely, the user interface for this feature is built almost entirely with **SwiftUI**, hosted within the app's older UIKit navigation structure. The settings themselves are defined in a centralized, type-safe manner and stored in `UserDefaults`.

## 2. Architecture and Data Flow

The settings architecture is a great example of the "strangler fig" pattern, where a new SwiftUI implementation is progressively replacing an older one.

### 2.1. UI Layer (SwiftUI)

-   **Hosting Controller (`SettingsViewController.swift`):** This is a UIKit `UIViewController` that subclasses `HostingController`. Its primary role is to act as a bridge between the UIKit-based `UITabBarController` and the new SwiftUI settings screen. It initializes and hosts a `SettingsContainerView`.
-   **Container View (`SettingsContainerView`):** A SwiftUI `View` defined inside `SettingsViewController.swift`. It's responsible for fetching necessary data from the environment (like the current `User` from the Core Data context) and passing it, along with callbacks for actions like "Log Out", down to the main settings view.
-   **Main View (`SettingsView`):** Located in the `AwfulSettingsUI` Swift package, this is the pure SwiftUI view that renders the entire settings screen. It's composed of standard SwiftUI components like `Form`, `Toggle`, `Picker`, and `Stepper`.

### 2.2. Data & State Management

-   **Settings Definition (`Settings.swift`):** Located in the `AwfulSettings` Swift package, this file is the single source of truth for all available settings.
    -   It uses a `Settings` enum as a namespace.
    -   Each setting is a `static let` property, defined using a generic `Setting<T>` struct that holds its `UserDefaults` key and a default value (e.g., `public static let autoplayGIFs = Setting(key: "autoplay_gifs", default: false)`).
    -   This provides a centralized, type-safe way to reference settings throughout the app.

-   **`@FoilDefaultStorage` Property Wrapper:** This custom property wrapper (and the standard SwiftUI `@AppStorage`) acts as the bridge between the UI and `UserDefaults`.
    -   In `SettingsView`, a property like `@FoilDefaultStorage(Settings.autoplayGIFs) private var autoplayGIFs` creates a two-way binding.
    -   The `Toggle` in the UI is bound to the `autoplayGIFs` property.
    -   When the user taps the toggle, the property wrapper automatically updates the value in memory and writes the new value to `UserDefaults` using the key specified in `Settings.autoplayGIFs`.

-   **`UserDefaults`**: This is the underlying persistence mechanism for all settings.

## 3. Key Files & Code Components

-   **UI Entry Point:** `App/Settings/SettingsViewController.swift` (UIKit Hosting Controller)
-   **SwiftUI Views:** `AwfulSettingsUI/Sources/AwfulSettingsUI/SettingsView.swift`
-   **Settings Definitions:** `AwfulSettings/Sources/AwfulSettings/Settings.swift`
-   **UserDefaults Binding:** `AwfulSettings/Sources/AwfulSettings/FoilDefaultStorage+Setting.swift`

## 4. Full List of Settings

The `Settings.swift` file defines the following user-configurable settings, which are all stored in `UserDefaults`:

*   **Appearance & Theming:**
    *   `appIconName`: The name of the selected alternate app icon.
    *   `autoDarkTheme`: Whether to follow the system's dark mode.
    *   `darkMode`: Whether dark mode is explicitly enabled.
    *   `defaultDarkThemeName`, `defaultLightThemeName`: The names of the default themes for each mode.
    *   `fontScale`: The percentage to scale the post font size.
    *   `hideSidebarInLandscape`: Hides the sidebar on iPad in landscape.
    *   `showAvatars`: Show user avatars in posts.
    *   `showThreadTags`: Show thread tag icons in thread lists.
    *   `themeBYOB`, `themeFYAD`, etc.: Forum-specific theme overrides.

*   **Feature Toggles:**
    *   `automaticTimg`: Automatically wrap large images in `[timg]` tags.
    *   `autoplayGIFs`: Animate GIFs automatically.
    *   `clipboardURLEnabled`: Check the clipboard for forum URLs on app launch.
    *   `confirmBeforeReplying`: Show a preview screen before posting a reply.
    *   `embedBlueskyPosts`, `embedTweets`: Toggle embedding for social media links.
    *   `enableCustomTitlePostLayout`: Show user custom titles.
    *   `enableHaptics`: Enable haptic feedback.
    *   `frogAndGhostEnabled`: Show animated pull-to-refresh controls.
    *   `handoffEnabled`: Enable Handoff support.
    *   `jumpToPostEndOnDoubleTap`: Change double-tap behavior on a post.
    *   `loadImages`: Load images in posts.
    *   `pullForNext`: Pull up to load the next page of a thread.
    *   `showUnreadAnnouncementsBadge`: Show a badge for unread announcements.

*   **Account & Data (Marked in code as "shouldn't be a setting"):**
    *   `canSendPrivateMessages`: A capability of the user's account.
    *   `userID`, `username`: The logged-in user's credentials. *These should ideally be in the Keychain.*

*   **External Integrations:**
    *   `defaultBrowser`: Which browser to use for external links.
    *   `imgurUploadMode`: How to handle Imgur uploads (Off, Anonymous, Authenticated).
    *   `openTwitterLinksInTwitter`, `openYouTubeLinksInYouTube`: Open specific links in their native apps.

## 5. Modernization Plan

This feature is already in an excellent state, having been largely migrated to SwiftUI. The modernization path from here is about refining the architecture and cleaning up the remaining legacy pieces.

-   **Remove Hosting Controller:** Once the entire application's navigation is SwiftUI-native (e.g., using a `TabView`), `SettingsViewController` can be deleted entirely. The `SettingsContainerView` (or its contents) would become a direct tab in the main `TabView`.
-   **Consolidate State:** The callbacks for `logOut` and `emptyCache` are passed down from the UIKit world. In a fully SwiftUI app, these would be handled by calling methods on an `ObservableObject` (like a `SessionManager` or `CacheManager`) that is injected into the SwiftUI `Environment`.
-   **Relocate Session Data:** The `userID` and `username` settings should be removed from `UserDefaults`. As proposed in `Persistence.md`, this data belongs in the **Keychain** and should be managed by a dedicated `SessionManager` service. The settings screen would then read the username for display from that service rather than from `UserDefaults`.
-   **Relocate Account Capabilities:** The `canSendPrivateMessages` flag is a property of the user's account, not a device setting. This should be fetched along with other user profile data and stored in the Core Data cache, not `UserDefaults`. 