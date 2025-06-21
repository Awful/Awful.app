# Feature: Data Persistence & Session Management

**Last Updated:** 2024-07-29

## 1. Summary

The application uses two primary mechanisms for data persistence: a Core Data stack for caching scraped forum data, and the shared `HTTPCookieStorage` for managing the user's logged-in session. The two systems are largely separate but are often cleared simultaneously, such as during a logout.

## 2. Core Data

The Core Data stack is used as a cache for data scraped from the Something Awful forums. This avoids re-fetching and re-parsing data for things like forum lists, thread lists, user profiles, and seen posts.

### 2.1. Architecture

-   **`DataStore.swift`**: Located in the `AwfulCore` module, this class is the heart of the persistence layer. It does **not** use the modern `NSPersistentContainer`. Instead, it manually constructs the Core Data stack:
    1.  It loads the data model from `Awful.momd` (the compiled version of `Awful.xcdatamodeld`).
    2.  It creates a `NSPersistentStoreCoordinator` from the model.
    3.  It creates a main-thread `NSManagedObjectContext` and connects it to the coordinator.
    4.  It adds a `NSSQLiteStoreType` persistent store to the coordinator, located at `AwfulCache.sqlite` in the Application Support directory. This directory is excluded from device backups.

-   **Saving Data**: The `DataStore` listens for the `UIApplication.didEnterBackgroundNotification` and automatically saves the `mainManagedObjectContext` when the app is backgrounded.

-   **Data Model (`Awful.xcdatamodeld`)**: The model contains entities for all major forum objects, including:
    -   `Forum`, `ForumCategory`
    -   `AwfulThread` (named to avoid conflict with `Thread`)
    -   `Post`
    -   `User`
    -   `PrivateMessage`
    -   ...and others.

-   **Data Pruning**: The `DataStore` also includes a `CachePruner` mechanism that runs on a timer to periodically clean out old or unnecessary cached data.

### 2.2. Data Flow

1.  The `AppDelegate` initializes a singleton `DataStore` instance on startup.
2.  The `ForumsClient` (the networking layer) is given a reference to the `DataStore`'s `mainManagedObjectContext`.
3.  After `ForumsClient` fetches and scrapes data from the network, the resulting objects are "upserted" (updated or inserted) into a background managed object context and saved.
4.  These changes are then merged back into the `mainManagedObjectContext` for the UI to display.

## 3. Session Management (Login Cookie)

The user's session is not stored in Core Data or `UserDefaults`. It relies entirely on the presence of a specific cookie in the shared cookie storage.

### 3.1. Architecture

-   **`HTTPCookieStorage.shared`**: This is the global, system-provided singleton for storing all web cookies. The app uses this as the sole source of truth for the user's session.
-   **Session Cookie**: The specific cookie that signifies a valid session is named `bbuserid`.
-   **`ForumsClient.isLoggedIn`**: The check for whether a user is logged in is a simple computed property in `ForumsClient.swift`. It queries `HTTPCookieStorage.shared` for cookies matching the forums' base URL and returns `true` if a cookie named `bbuserid` is found.
-   **`ForumsClient.loginCookieExpiryDate`**: This property retrieves the expiration date directly from the `bbuserid` cookie instance.

### 3.2. Data Flow

1.  **Login**: When a user logs in via `ForumsClient.logIn(...)`, the networking layer makes a `POST` request to the server. If successful, the server's response includes a `Set-Cookie` header, and `URLSession` automatically stores the `bbuserid` cookie in `HTTPCookieStorage.shared`.
2.  **Authenticated Requests**: For all subsequent requests, `URLSession` automatically attaches the `bbuserid` cookie, authenticating the user with the server.
3.  **Logout**: When the user logs out via `AppDelegate.logOut()`, two things happen:
    -   All cookies in `HTTPCookieStorage.shared` are deleted.
    -   The entire Core Data store is deleted via `DataStore.deleteStoreAndReset()`.
    This ensures a clean slate, with no session or cached data remaining.

## 4. Legacy Code & Modernization Plan

-   **Pain Points:**
    -   The Core Data stack is set up manually, which is verbose and misses out on the conveniences and optimizations of the modern `NSPersistentContainer`.
    -   Relying directly on the state of the global `HTTPCookieStorage` for session logic tightly couples the `ForumsClient` to the networking layer's side effects.
    -   There is no single, observable "source of truth" for the user's session state. The app must imperatively check `ForumsClient.isLoggedIn` at various points.

-   **Proposed Changes (SwiftUI):**
    -   **Adopt `NSPersistentContainer`**: Refactor `DataStore` to use `NSPersistentContainer`, which simplifies setup, context management, and background tasks.
    -   **Create a Session Manager**: Introduce a dedicated `SessionManager` or `AuthenticationService` as an `ObservableObject`.
        -   This service would be responsible for login, logout, and securely storing session information.
        -   Instead of just checking for a cookie, upon successful login, it could securely store essential user info (like user ID and username) in the **Keychain**. The Keychain is the standard, secure place for sensitive data like this.
        -   The manager would publish the user's authentication state (e.g., `case .loggedIn(User)`, `case .loggedOut`).
    -   **Inject as Environment Object**: An instance of this `SessionManager` would be injected into the SwiftUI `Environment`.
        ```swift
        @main
        struct AwfulApp: App {
            @StateObject private var sessionManager = SessionManager()

            var body: some Scene {
                WindowGroup {
                    RootView()
                        .environmentObject(sessionManager)
                }
            }
        }
        ```
    -   **Declarative UI**: Views could then react declaratively to changes in the authentication state.
        ```swift
        struct RootView: View {
            @EnvironmentObject private var sessionManager: SessionManager

            var body: some View {
                switch sessionManager.state {
                case .loggedIn:
                    MainTabView()
                case .loggedOut:
                    LoginView()
                }
            }
        }
        ```
    This approach decouples session state from the cookie storage, provides a single, observable source of truth, and uses modern, secure storage practices. 