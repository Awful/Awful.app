# Feature: Theming

**Last Updated:** 2024-07-29

## 1. Summary

The application employs a robust, file-based theming system that allows for extensive UI customization. Themes are defined in a central property list (`.plist`) file and are applied at runtime to various UI components. The system supports inheritance, allowing themes to be built on top of a "default" base theme.

## 2. Architecture and Data Flow

The theming system can be broken down into three main parts: Definition, Loading, and Application.

### 2.1. Theme Definition (`Themes.plist`)

- **Location:** `AwfulTheming/Sources/AwfulTheming/Themes.plist`
- **Structure:** The plist is a dictionary where each key is a unique theme name (e.g., "default", "dark", "OLED Dark"). The value is another dictionary containing the theme's properties.
- **Properties:** Properties are key-value pairs that define colors, font styles, keyboard appearance, and references to CSS files. They are often grouped into sub-dictionaries for organization (e.g., `<dict>` for `Lists`, `Posts`, etc.), but these are flattened into a single-level dictionary at runtime.
- **Inheritance:** A theme can specify a `parent` key. If a property is not found in a given theme, the system traverses up the inheritance chain to its parent, ultimately falling back to the "default" theme.

### 2.2. Theme Loading (`Themes.swift`)

- **Location:** `AwfulTheming/Sources/AwfulTheming/Themes.swift`
- **`Theme` Class:** This class represents a single theme. On app startup, a static dictionary `bundledThemes` is initialized, loading all themes from `Themes.plist` into memory as `Theme` objects.
- **Accessing Properties:** The `Theme` class provides custom subscripts to access theme properties in a type-safe way. For example:
    - `theme[uicolor: "backgroundColor"]` returns a `UIColor`. It can parse hex strings (`#RRGGBBAA`) and also load `UIColor` from a pattern image.
    - `theme[string: "postsViewCSS"]` returns a `String`.
    - `theme[bool: "roundedFonts"]` returns a `Bool`.

- **Theme Resolution:** The entry point for getting the correct theme for any given view is the static method `Theme.currentTheme(for:)`. This method first checks if the user has set a specific theme for the given forum ID. If a forum-specific theme exists, it is returned. Otherwise, it returns the user's selected global theme. This allows for fine-grained customization on a per-forum basis.

### 2.3. Theme Application (`Themeable` Protocol)

- **`Themeable` Protocol:** Found in `AwfulTheming/Sources/AwfulTheming/ViewController.swift`, this protocol defines the contract for any UI component that can be themed. It requires a single method: `themeDidChange()`.
- **Adoption:** Many base classes and specific views adopt this protocol, including `AwfulTheming.ViewController`, `AwfulTheming.TableViewController`, `RootTabBarController`, and `NavigationController`.
- **Update Mechanism:** When the app's theme is changed, the `AppDelegate` walks the currently active view controller hierarchy. For each view controller that conforms to `Themeable`, it calls the `themeDidChange()` method.
- **Implementation:** Inside `themeDidChange()`, each component is responsible for reading the new theme's properties and updating its appearance (e.g., setting background colors, tint colors, text attributes, etc.).

## 3. Full List of Theme Properties

The following is a comprehensive list of all properties found across all themes in `Themes.plist`:

*   **Top Level:**
    *   `parent`: (String) The name of the parent theme.
    *   `mode`: (String) "light" or "dark".
    *   `description`: (String) A user-facing description of the theme.
    *   `descriptiveColor`: (Color) A color used to represent the theme in UI.
    *   `descriptiveName`: (String) The user-facing name of the theme.
    *   `tintColor`: (Color) The global tint color for interactive elements.
    *   `backgroundColor`: (Color) The default background color for most views.
    *   `scrollIndicatorStyle`: (String) "Light" or "Dark".
    *   `keyboardAppearance`: (String) "Light" or "Dark".
    *   `placeholderTextColor`: (Color)
    *   `favoriteStarTintColor`: (Color)
    *   `settingsSwitchColor`: (Color)
    *   `roundedFonts`: (Bool)
    *   `actionIconTintColor`: (Color)
    *   `statusBarBackground`: (String)

*   **Lists (`<dict>key="Lists"`):**
    *   `listHeaderTextColor`, `listHeaderBackgroundColor`: (Color)
    *   `listTextColor`, `listSecondaryTextColor`: (Color)
    *   `listSeparatorColor`, `listBackgroundColor`, `listSelectedBackgroundColor`: (Color)
    *   `ratingIconEmptyColor`: (Color)
    *   `expansionTintColor`: (Color)
    *   `unreadPostCountFontSizeAdjustment`: (String representing an Int)
    *   `messageListSenderFontSizeAdjustment`, `messageListSentDateFontSizeAdjustment`, `messageListSubjectFontSizeAdjustment`: (Integer)
    *   `threadListPageIconColor`: (Color)

*   **Lotties (`<dict>key="Lotties"`):**
    *   `getOutFrogColor`, `nigglyColor`: (Color)

*   **Navbar, tab bar, toolbar (`<dict>key="Navbar, tab bar, toolbar"`):**
    *   `bottomBarTopBorderColor`: (Color)
    *   `showRootTabBarLabel`: (Bool)
    *   `tabBarTintColor`, `tabBarIconNormalColor`, `tabBarIconSelectedColor`, `tabBarBackgroundColor`, `tabBarIsTranslucent`: (Color/Bool)
    *   `navigationBarTextColor`, `navigationBarTintColor`: (Color)
    *   `toolbarTextColor`, `toolbarTintColor`: (Color)

*   **Posts (`<dict>key="Posts"`):**
    *   `postTitleFontSizeAdjustmentPhone`, `postTitleFontSizeAdjustmentPad`: (Integer)
    *   `postTitleFontWeightPhone`, `postTitleFontWeightPad`: (String) "semibold", etc.
    *   `postsLoadingViewTintColor`, `postsPullForNextColor`: (Color)
    *   `postsTopBarTextColor`, `postsTopBarBackgroundColor`: (Color)
    *   `postsTweetTheme`: (String) "light" or "dark" for embedded tweets.
    *   `postsViewCSS`: (String) Name of the CSS file for styling posts.

*   **Sheets (`<dict>key="Sheets"`):**
    *   `sheetBackgroundColor`, `sheetTitleColor`, `sheetTitleBackgroundColor`, `sheetTextColor`, `sheetDimColor`: (Color)

*   **Tag picker (`<dict>key="Tag picker"`):**
    *   `tagPickerTextColor`, `tagPickerBackgroundColor`: (Color)

*   **Unread badges (`<dict>key="Unread badges"`):**
    *   `unreadBadgeBlueColor`, `unreadBadgeGrayColor`, etc. (one for each color): (Color)

## 4. Legacy Code & Modernization Plan

- **Pain Points:**
    - The system relies on a protocol (`Themeable`) and an imperative update loop (`themeDidChange()`) that forces each view to manually reset its appearance properties. This is boilerplate-heavy and error-prone.
    - Colors and other properties are scattered throughout view controller code, making it hard to see the full picture of a component's styling in one place.
    - It's not reactive. Changes require a manual trigger and a loop through the view hierarchy.

- **Proposed Changes (SwiftUI):**
    - **Centralized Theme Object:** Create a single `Theme` struct that can be decoded directly from the plist's theme dictionaries. This struct would hold all theme properties as `Color`, `Font`, etc.
    - **Environment-Based Theming:** Create a custom `EnvironmentKey` for the current theme.
        ```swift
        private struct ThemeKey: EnvironmentKey {
            static let defaultValue: Theme = .default // a default theme
        }

        extension EnvironmentValues {
            var theme: Theme {
                get { self[ThemeKey.self] }
                set { self[ThemeKey.self] = newValue }
            }
        }
        ```
    - **Theme Provider View:** A root-level view would be responsible for observing the current theme setting (e.g., from `UserDefaults`) and injecting the correct `Theme` object into the environment.
        ```swift
        struct ThemeProvider<Content: View>: View {
            @StateObject private var themeManager = ThemeManager() // an ObservableObject that holds the current theme
            let content: () -> Content

            var body: some View {
                content()
                    .environment(\.theme, themeManager.currentTheme)
            }
        }
        ```
    - **Declarative Styles:** Instead of `themeDidChange()`, views would be styled declaratively using the theme from the environment. Custom `ViewModifier`s can be created for reusable styles.
        ```swift
        struct PrimaryBackground: ViewModifier {
            @Environment(\.theme) private var theme
            func body(content: Content) -> some View {
                content.background(theme.backgroundColor)
            }
        }

        Text("Hello, World!")
            .foregroundColor(theme.textColor) // Direct access
            .modifier(PrimaryBackground())   // Using a modifier
        ```
    This approach is fully declarative, reactive, and aligns perfectly with SwiftUI's design principles, removing the need for manual update loops and making the code much cleaner and easier to maintain. 