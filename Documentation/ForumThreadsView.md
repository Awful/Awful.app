# Forum Threads View

This view displays the list of threads for a single forum. It is functionally similar to the Bookmarks view but is populated with data from a specific forum rather than the user's bookmarked threads. It includes features for pagination (infinite scrolling), pull-to-refresh, and filtering by thread tag.

## Components

-   **`ThreadsTableViewController`**: The primary `UITableViewController` for this screen. It is initialized with a `Forum` object and is responsible for managing the view, fetching data from the network, and handling user interactions like filtering.

-   **`ThreadListDataSource`**: The same reusable data source used by the `BookmarksTableViewController`. For this view, it's initialized with a `Forum` object, which causes its internal `NSFetchRequest` to be configured with a predicate that fetches only threads belonging to that forum (`forum == %@`).

-   **`ThreadListCell`**: The `UITableViewCell` used to display a single thread in the list. It's responsible for displaying the thread's primary and secondary tags, its rating, title, author, page count, and unread count.

-   **`ThreadListCell.ViewModel`**: A `struct` that acts as a view model for the `ThreadListCell`. The `ThreadListDataSource` creates an instance of this view model for each thread, transforming the raw `AwfulThread` model data into formatted `NSAttributedString`s and `UIImage`s suitable for direct display.

-   **`ThreadTagPickerViewController`**: A view controller that is likely presented when the user taps the "Filter by tag" button, allowing them to select a tag to filter the list.

## Data Flow

1.  An instance of `ThreadsTableViewController` is created and passed a `Forum` object.
2.  The view controller initializes a `ThreadListDataSource`, providing it with the `Forum` object. The data source sets up an `NSFetchedResultsController` to fetch the relevant `AwfulThread` entities from the local Core Data cache.
3.  When the view appears, if a refresh is needed, the `refresh()` method calls `ForumsClient.shared.listThreads(in: forum, ...)` to fetch the latest list of threads from the network for the given forum and page.
4.  The fetched thread data is saved into Core Data.
5.  The `NSFetchedResultsController` automatically detects the changes in Core Data and notifies the `ThreadListDataSource`.
6.  For each thread, the `ThreadListDataSource` creates a `ThreadListCell.ViewModel`. This involves:
    -   Mapping the thread's rating (e.g., `3.5`) to the correct rating image (e.g., `rating3.5.png`).
    -   Creating `NSAttributedString`s for the title, author, and other text labels, applying the correct fonts and colors from the current theme.
    -   Passing the thread tag image names to the view model.
7.  The data source configures a `ThreadListCell` with the `ViewModel`. The cell then uses `ThreadTagLoader` to load the tag images and displays all the other information.

## Modernization Plan

The architecture here is very similar to the Bookmarks view, and so is the modernization plan.

-   **SwiftUI List**: The `ThreadsTableViewController` can be replaced with a SwiftUI `View`. This view would contain a `List` that iterates over the threads.
-   **State Management**: The new SwiftUI view would hold the `Forum` as a property. It would use the `@State` or `@StateObject` property wrappers to manage the current page, filter tag, and loading state.
-   **Native Data Flow**: The `List` would be populated by a fetch request, which could be managed by a `@FetchRequest` property wrapper if using SwiftUI's Core Data integration, or by a custom `ObservableObject` view model that encapsulates the fetching logic.
-   **Cell as a View**: The `ThreadListCell` would be rewritten as a `View` struct. This new view would use `HStack` and `VStack` with `Spacer`s to achieve the complex layout, which would be far simpler and less error-prone than the manual frame calculations in the current `layoutSubviews()` method. It would use `NukeUI`'s `LazyImage` to load the thread tags. 