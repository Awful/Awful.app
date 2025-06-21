# Bookmarks View

The Bookmarks tab displays a list of all threads that the user has bookmarked. It provides features for sorting, infinite scrolling, and removing bookmarks.

## Components

- **`BookmarksTableViewController`**: The primary `UITableViewController` for this screen. It manages the view's lifecycle, handles user interactions like pull-to-refresh and editing, and initiates data loading.
- **`ThreadListDataSource`**: A reusable data source object that populates the `UITableView`. This same data source class is also used to display the list of threads within a single forum.
- **`ThreadListCell`**: A custom `UITableViewCell` for displaying a thread. It shows the thread's title, tags, author, last post info, and unread count.
- **`LoadMoreFooter`**: A custom view that appears at the bottom of the table, allowing the user to load subsequent pages of their bookmarks.
- **`AwfulThread` (Model)**: The Core Data entity representing a forum thread. The `bookmarked` attribute is a boolean flag that indicates whether the thread should appear in this list.

## Data Flow & Persistence

The data flow for bookmarks is nearly identical to the Forums view, demonstrating a consistent architectural pattern in the app.

1.  **Network Fetch**: When a refresh is triggered, `BookmarksTableViewController` calls `ForumsClient.shared.listBookmarkedThreads(page:)`. This fetches a paginated list of bookmarked threads from the server.
2.  **Core Data Caching**: The fetched thread data is parsed and upserted into the Core Data store. The `bookmarked` property on the `AwfulThread` entities is set to `true`.
3.  **Fetched Results Controller**: The `ThreadListDataSource` is initialized with a specific `NSFetchRequest` for this screen:
    -   **Predicate**: It fetches `AwfulThread` entities where `bookmarked == YES`.
    -   **Sort Descriptors**: It sorts threads based on user preference, either with unread threads at the top or by the date of the last post.
    -   This request is wrapped in an `NSFetchedResultsController`, which drives the `UITableView`.
4.  **UI Updates**: The `NSFetchedResultsControllerDelegate` methods within `ThreadListDataSource` handle all insertions, deletions, and updates, animating the changes in the `UITableView` automatically when the underlying Core Data store is modified.
5.  **Infinite Scroll**: When the user scrolls to the bottom, the `LoadMoreFooter` triggers `loadPage(page:)` in the view controller, which fetches the next page of bookmarks from the network, adds them to the Core Data store, and lets the `NSFetchedResultsController` seamlessly insert the new rows into the table.

## User Interactions

- **Sorting**: The user can change the sort order in the app's Settings. The `BookmarksTableViewController` observes this setting and, if it changes, recreates the `ThreadListDataSource` with the new sort descriptors and reloads the table.
- **Deletion**: Users can swipe to delete a bookmark. This action calls `setThread(_:isBookmarked:)`, which:
    1.  Immediately sets the `bookmarked` property on the `AwfulThread` object to `false`. This causes the `NSFetchedResultsController` to remove the row from the table view automatically.
    2.  Registers an `UndoManager` action to allow the user to revert the deletion.
    3.  Sends a network request to the Something Awful server to permanently remove the bookmark.

## Modernization Plan

The modernization path for the Bookmarks view is very similar to the Forums view.

- **Replace `UITableViewController` with a SwiftUI `List`**: Convert `BookmarksTableViewController` into a pure SwiftUI `View`.
- **Replace `NSFetchedResultsController` with `@FetchRequest`**: The `ThreadListDataSource` can be eliminated. A `@FetchRequest` property wrapper within the new SwiftUI view can be configured with the appropriate predicate (`bookmarked == YES`) and sort descriptors to fetch the data directly.
- **Simplify State Management**: Settings that affect the UI, like the sort order, can be managed with `@AppStorage` or a dedicated `ObservableObject` settings store. Changes to these properties will automatically cause the SwiftUI view's body to be re-evaluated, which in turn will re-fetch the data with the updated sort descriptors.
- **Infinite Scroll**: The "load more" logic can be implemented in SwiftUI by adding a `ProgressView` at the bottom of the `List`. When this view appears (`.onAppear`), it can trigger the `loadPage()` async function.
- **Deletion**: The `.onDelete` modifier on a SwiftUI `ForEach` loop provides a direct way to implement swipe-to-delete functionality, simplifying the current implementation. 