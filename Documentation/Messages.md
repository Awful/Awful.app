# Private Messages View

The Private Messages tab provides an interface for viewing and managing private messages (PMs). It lists all messages in the user's inbox, shows their read/unread status, and allows for composing, reading, and deleting messages.

## Components

- **`MessageListViewController`**: The main `UITableViewController` for the message inbox. It handles refreshing the message list, navigation to individual messages, and presenting the composition view.
- **`MessageListDataSource`**: The data source object for the `UITableView`. It's responsible for fetching the messages from Core Data and providing them to the table view.
- **`MessageListCell`**: A custom `UITableViewCell` that displays a single message preview, including the sender, subject, date, and status icons (unread, replied, forwarded).
- **`PrivateMessage` (Model)**: The Core Data entity representing a single private message.
- **`MessageViewController`**: An **Objective-C** based `UIViewController` (`MessageViewController.m`) responsible for displaying the full content of a single private message thread.
- **`MessageComposeViewController`**: A `UIViewController` for writing and sending new private messages.

## Data Flow & Persistence

The data flow follows the app's standard pattern of network-fetch-and-cache.

1.  **Network Fetch**: When a refresh is triggered, `MessageListViewController` calls `ForumsClient.shared.listPrivateMessagesInInbox()`. This fetches the user's inbox from the server.
2.  **Core Data Caching**: The fetched message data is parsed and upserted into the Core Data store as `PrivateMessage` objects.
3.  **Fetched Results Controller**: The `MessageListDataSource` configures an `NSFetchedResultsController` to fetch all `PrivateMessage` objects from the cache, sorted by the date they were sent (`sentDate`).
4.  **UI Updates**: The `NSFetchedResultsControllerDelegate` implementation within the data source automatically updates the `UITableView` with animations whenever the underlying `PrivateMessage` data changes in Core Data.

A `ManagedObjectCountObserver` is also used to monitor the number of unseen messages and update the tab bar item's badge value accordingly.

## Navigation & Composition

- **Reading a Message**: Tapping a cell in the list pushes an instance of the Objective-C `MessageViewController`, which loads and displays the selected message's content.
- **Composing a Message**: Tapping the "Compose" button modally presents a `MessageComposeViewController`.

## Modernization Plan

The modernization strategy for the Messages tab is consistent with the other list-based tabs.

- **Replace `UITableViewController` with a SwiftUI `List`**: `MessageListViewController` can be rewritten as a SwiftUI `View` containing a `List`.
- **Replace `NSFetchedResultsController` with `@FetchRequest`**: The `MessageListDataSource` can be eliminated in favor of a `@FetchRequest` property wrapper within the new SwiftUI view. The fetch request would be configured to fetch `PrivateMessage` entities, sorted by `sentDate`.
- **Simplify State and Navigation**: Navigation to the message detail view would be handled by `NavigationLink`. Presenting the compose view would be handled by the `.sheet` modifier in SwiftUI.
- **Rewrite Objective-C Components in Swift/SwiftUI**: A significant modernization step would be to rewrite the Objective-C `MessageViewController` in Swift and SwiftUI. This would improve maintainability, type safety, and allow for a more consistent architecture across the entire feature. The `MessageComposeViewController` could similarly be converted to a pure SwiftUI view. 