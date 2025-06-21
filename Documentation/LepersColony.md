# Leper's Colony View

The Leper's Colony tab displays a list of the most recent punishments (bans and probations) handed out across the Something Awful forums. It serves as a forum-wide record of moderation actions.

## Components

- **`RapSheetViewController`**: A dual-purpose `UITableViewController`. When initialized without a specific user, it functions as the Leper's Colony. When initialized *with* a user, it displays that specific user's punishment history (their "rap sheet").
- **`PunishmentCell`**: A custom `UITableViewCell` designed to show a single punishment record. It displays the username of the banned user, the name of the moderator who issued the ban, the date, and the reason for the punishment.
- **`LepersColonyScrapeResult.Punishment`**: A data structure that holds the scraped information for a single punishment. This is not a Core Data entity.

## Data Flow

The data flow for the Leper's Colony is the simplest of all the main tabs, as it does **not** use Core Data for caching.

1.  **Network-Only**: This feature is network-only. The `RapSheetViewController` calls `ForumsClient.shared.listPunishments(of: nil, page: page)` to fetch data.
2.  **HTML Scraping**: The `ForumsClient` makes a network request to the `leperscolony.php` page on the Something Awful website. The resulting HTML is then scraped to extract a list of punishments.
3.  **In-Memory Storage**: The scraped data is parsed into an array of `LepersColonyScrapeResult.Punishment` objects. This array is stored directly in an `NSMutableOrderedSet` property within the `RapSheetViewController`. The data only persists in memory for the lifetime of the view controller.
4.  **Direct Data Source**: The `RapSheetViewController` acts as its own `UITableViewDataSource`, feeding the data directly from its internal `punishments` set to the table view. There is no `NSFetchedResultsController` or other complex data management layer.

## User Interactions

- **Infinite Scroll**: The view implements "load more" functionality to fetch and display subsequent pages of the Leper's Colony.
- **Navigation**: Tapping on any punishment cell navigates the user directly to the forum post that was the cause of the ban, allowing them to see the context of the moderation action.

## Modernization Plan

Modernizing this view would involve replacing the UIKit components and simplifying the data loading and display logic.

- **Replace `UITableViewController` with a SwiftUI `List`**: The `RapSheetViewController` can be rewritten as a SwiftUI `View`. The `List` would iterate over a state variable holding the array of punishments.
- **Simplify Data Loading with `.task`**: The `async` `listPunishments` function can be called from a `.task` modifier attached to the SwiftUI view. The results would be stored in a `@State` array.
- **State-Driven UI**: The logic for showing an empty state or the list of punishments would be handled declaratively within the `body` of the SwiftUI view, based on the state of the punishments array.
- **Infinite Scroll**: The "load more" functionality can be implemented by placing a `ProgressView` at the end of the `List`. When the `.onAppear` modifier of that `ProgressView` is triggered, the next page of data can be fetched and appended to the state array.
- **Navigation**: `NavigationLink` would be used to handle navigation to the associated post for each punishment. 