# Forums View

The Forums tab (`ForumsTableViewController`) is the initial view presented to the user after they have logged in. It displays a hierarchical list of all forums available on the Something Awful forums, grouped by category. It also provides sections for announcements and user-favorited forums.

## Components

- **`ForumsTableViewController`**: The main view controller for this screen. It's a `UITableViewController` subclass responsible for setting up the view, handling user interaction, and kicking off data refreshes.
- **`ForumListDataSource`**: A dedicated data source object that manages the complexity of populating the `UITableView`. It's responsible for fetching data from Core Data and responding to changes.
- **`ForumListCell`**: A custom `UITableViewCell` for displaying a single forum.
- **`AwfulForum` (Model)**: The Core Data entity representing a single forum.
- **`ForumMetadata` (Model)**: A separate Core Data entity that stores user-specific data about a forum, such as whether it's a favorite (`favorite`), its position in the favorites list (`favoriteIndex`), and its expansion state in the UI (`showsChildrenInForumList`). This separation keeps the core `Forum` model clean of user-specific state.
- **`Announcement` (Model)**: The Core Data entity for a forum announcement.

## Data Flow & Persistence

The data flow for the forums list is more complex than other tabs because it combines three different data sources into a single, unified view.

1.  **Network Fetch**: When a refresh is triggered, `ForumsTableViewController` calls `ForumsClient.shared.taxonomizeForums()`. This fetches a list of all forums and their parent categories from the server.
2.  **Core Data Caching**: The fetched data is parsed and "upserted" into the Core Data store. This populates the `Forum` and `ForumCategory` entities.
3.  **Fetched Results Controllers**: The `ForumListDataSource` does not use one, but **three** separate `NSFetchedResultsController` instances to build the list:
    -   An `announcementsController` fetches any active announcements.
    -   A `favoriteForumsController` fetches forums that the user has marked as a favorite.
    -   A `forumsController` fetches all other forums, grouped by their parent `ForumCategory`.
4.  **Data Source Combination**: The `ForumListDataSource` then acts as a facade, mapping the sections from these three individual controllers into a single, unified list for the `UITableView`. This creates the illusion of a single list with different sections (Announcements, Favorites, and then forum categories).
5.  **UI Updates**: The `NSFetchedResultsControllerDelegate` methods within `ForumListDataSource` handle all insertions, deletions, and updates from Core Data, animating the changes in the table view.

## Navigation

- Tapping on a forum cell calls `openForum(_:animated:)` on the `ForumsTableViewController`, which creates an instance of `ThreadsTableViewController` configured for that specific forum and pushes it onto the `UINavigationController`'s stack.
- Tapping on an announcement opens the `AnnouncementViewController`.

## Modernization Plan

The current implementation is a well-structured example of a pre-SwiftUI, UIKit/Core Data application. However, it relies on several patterns that can be greatly simplified with modern frameworks.

- **Replace `UITableViewController` with a SwiftUI `List`**: The entire view can be rebuilt as a SwiftUI `View`. The `List` view is the natural replacement for `UITableView`.
- **Replace `NSFetchedResultsController` with `@FetchRequest`**: SwiftUI's `@FetchRequest` property wrapper can replace the manual setup and delegation of `NSFetchedResultsController`. We can define separate fetch requests for announcements, favorite forums, and regular forums, and then compose them within the body of our SwiftUI `View`. This will declarative and significantly reduce the amount of boilerplate code in the data source.
- **Simplify the Data Source**: The complex logic inside `ForumListDataSource` for combining three FRCs and managing table updates would no longer be necessary. The SwiftUI `List` would be composed of different sections, each backed by its own `@FetchRequest`, and SwiftUI would handle all the view updates automatically.
- **Navigation**: `UINavigationController` can be replaced with `NavigationStack`, and the programmatic navigation (`navigationController?.pushViewController(...)`) would be replaced with SwiftUI's `NavigationLink`.
- **Data Refresh**: The `async/await` `taxonomizeForums()` method can be called directly from a SwiftUI view's `.task` modifier, which handles the lifecycle of the asynchronous operation correctly. 