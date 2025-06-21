# Feature: Smilies Keyboard & Data

**Last Updated:** 2024-07-29

## 1. Summary

The Smilies feature is a complex, multi-part system written almost entirely in Objective-C. It provides an in-app smilie picker, a system-wide custom keyboard for using smilies in other apps, and a mechanism for downloading and updating a smilie database from the Something Awful website.

The feature's architecture is defined by its data sharing model: it uses two separate Core Data persistent stores (one read-only for bundled smilies, one read-write for downloaded smilies) that are both accessed via a shared App Group container. This architecture is the source of the feature's primary build and runtime complexities.

## 2. Architecture and Data Flow

### 2.1. Data Layer (`Smilies` Swift Package)

The core logic resides in the `Smilies` package, which is an Objective-C target.

-   **`SmilieDataStore.m`**: This is the most critical component. It sets up a Core Data stack with **two persistent stores** attached to a single `NSPersistentStoreCoordinator`:
    1.  **Bundled Store:** A read-only SQLite file (`Smilies.sqlite`) included in the package's resources. This contains a list of pre-installed smilies and their image data.
    2.  **App Container Store:** A read-write SQLite file, also named `Smilies.sqlite`, located in a shared App Group container. This store is used to save smilies downloaded from the forums.

-   **`SmilieOperation.m`**: This is a custom `NSOperation` subclass responsible for scraping the smilies list page on the Something Awful forums, parsing the HTML, and populating the writable Core Data store with the results.

-   **Data Model:** The `Smilies.xcdatamodeld` file defines the `Smilie` entity, which stores the smilie's text (e.g., `:smith:`), image data, and metadata.

### 2.2. The Keyboard Extension (`Smilies Extra/Keyboard`)

This target builds the system-wide custom keyboard.

-   **`KeyboardViewController.m`**: This is the main view controller for the keyboard extension. It's an `UIInputViewController` subclass that lays out a `SmilieKeyboardView`.
-   **Data Access:** The `KeyboardViewController` initializes its own `SmilieDataStore`. Because it's running in a separate process, the **only way** it can access the user's downloaded smilies is through the shared App Group container.
-   **`Info.plist` Configuration:** The keyboard's `Info.plist` defines its properties, most importantly the `NSExtension` dictionary which sets the `RequestsOpenAccess` key to `YES`.

### 2.3. Build & Runtime Complications

The architecture gives rise to several key complications mentioned by the user:

1.  **App Groups:** For the main app and the keyboard extension to share the Core Data database, they **must** belong to the same App Group. This is configured in the "Signing & Capabilities" tab for both targets in Xcode and requires a paid Apple Developer account. The specific group identifier (e.g., `group.com.awfulapp.Awful`) is configured in the build settings and not checked into the entitlements file directly. This makes local builds difficult without proper setup.

2.  **"Full Access" Requirement:** The keyboard extension cannot access the network (to show smilie images) or write to the shared App Group container unless the user manually grants it "Full Access" in `Settings > General > Keyboard > Keyboards`. The code in `SmilieDataStore` explicitly checks for this (`if (SmilieKeyboardHasFullAccess())`) before attempting to load the writable database. This is a major point of friction and a common source of user support issues.

3.  **Data Caching:** Because the keyboard runs in its own process, smilie images are cached separately. The main app downloads and caches smilie images, and the keyboard does the same, leading to some data duplication.

## 4. Key Files & Code Components

-   **Core Data & Logic:** `Smilies/Sources/Smilies/SmilieDataStore.m`, `SmilieOperation.m` (Objective-C)
-   **Keyboard Extension Entry Point:** `Smilies Extra/Keyboard/KeyboardViewController.m` (Objective-C)
-   **Keyboard UI:** `Smilies/Sources/Smilies/SmilieKeyboardView.m` (Objective-C)
-   **App Group Entitlements:** Configured in the Xcode project's build settings for the `App` and `Smilies Extra/Keyboard` targets.

## 5. Modernization Plan

This feature is a prime candidate for a complete rewrite in Swift and modern frameworks.

-   **Deprecate Objective-C:** The entire `Smilies` package and `Smilies Extra` target should be rewritten in Swift to improve safety, maintainability, and performance.
-   **Simplify Data Storage:**
    -   The dual-store Core Data setup is clever but complex. A modern approach would be to use a single read-write database in the App Group container.
    -   On first launch, the app would check if the database is empty and, if so, populate it with the bundled "default" smilies. This eliminates the need for a read-only persistent store.
    -   Consider using a lighter-weight database solution like **GRDB.swift** if the full power of Core Data is not needed for this feature. GRDB is often easier to manage in a shared container context.
-   **Modern Networking:** Replace the `NSOperation`-based scraping with `async/await` calls using `URLSession`.
-   **SwiftUI Keyboard:** The keyboard's UI can be rewritten in SwiftUI. The `UIInputViewController` can host a SwiftUI view, which would make the layout code significantly cleaner and easier to manage.
-   **Improve "Full Access" UX:** While the "Full Access" requirement cannot be eliminated for a network-enabled keyboard, the user experience can be improved. The main app could detect if Full Access is disabled and present a clear, helpful guide showing the user exactly where to go in Settings to enable it.
-   **Unified Image Caching:** Use a shared image caching library (like Nuke, which is already a dependency) configured to use a directory within the App Group container. This would allow the main app and the keyboard to share a single image cache, reducing data usage and improving performance. 