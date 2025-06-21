# HTML Scraping, Parsing, and Persistence

The application's ability to display forum content is powered by a robust data pipeline that fetches raw HTML from the Something Awful forums, parses it to extract structured data, and then saves that data into a local Core Data store. This entire process is orchestrated by the `ForumsClient` class.

## Components

-   **`ForumsClient.swift`**: The singleton class that acts as the central point of contact with the Something Awful servers. It is responsible for making all network requests, handling authentication, and initiating the parsing and persistence process.

-   **`HTMLReader`**: A third-party library used for parsing raw HTML strings into a navigable Document Object Model (DOM) tree. It provides APIs for traversing the DOM and finding elements using CSS selectors, similar to libraries like BeautifulSoup in Python. The app accesses this library via the `AwfulScraping` Swift package.

-   **Scraped Models**: A collection of intermediate, `Codable` structs that represent the "pure" data extracted from an HTML page (e.g., `IndexScrapeResult`, which contains scraped user info and a list of forums). These models are decoupled from Core Data.

-   **Core Data Models**: The `NSManagedObject` subclasses that represent the persisted forum data (e.g., `Forum`, `Thread`, `User`).

## The Data Pipeline

The process for fetching and saving data is consistent across the application and follows a clear, thread-safe pattern.

1.  **Network Request**: A view controller or other high-level component calls a method on `ForumsClient.shared`, such as `listThreads(in: forum)`.

2.  **Fetch HTML**: The `ForumsClient` uses a private `fetch(...)` method to perform a `GET` or `POST` request using `URLSession`. It correctly encodes request parameters using the `windowsCP1252` character set required by the legacy forums software.

3.  **Choose Parser**: After receiving the raw `Data`, the `ForumsClient` decides how to interpret it:
    -   **JSON First**: If the request was made to an endpoint that supports JSON (e.g., by appending `?json=1` to the URL), it attempts to use `JSONDecoder` to decode the data into a `Codable` scraped model. This is the preferred, modern approach.
    -   **HTML Fallback**: If the JSON decoding fails, or if the endpoint is known to only return HTML, the `Data` is passed to `HTMLReader` to be parsed into a navigable `HTMLDocument`.

4.  **Scrape Data**: For HTML responses, the `HTMLDocument` is passed to a dedicated scraping function. These functions use `HTMLReader`'s CSS selector support (e.g., `document.nodes(matchingSelector: "tr.thread")`) to find the relevant HTML elements and extract their text content and attributes.

5.  **Populate Intermediate Models**: The raw strings and values extracted from the HTML are used to initialize instances of the intermediate scraped models. This step cleans and type-casts the data (e.g., converting a string like "1,234" into an `Int`).

6.  **Upsert to Core Data**: The array of scraped models is then passed to an `upsert(into:)` method. This method, often defined as an extension on the scraped model array, iterates through the models and performs the following for each one:
    a. It performs a fetch request on a **background** `NSManagedObjectContext` to see if a corresponding managed object already exists (e.g., a `Thread` with the same `threadID`).
    b. If the object exists, it updates its properties with the new data from the scraped model.
    c. If the object does not exist, it creates a new one.

7.  **Save to Persistent Store**: After the `upsert` operation is complete, `backgroundContext.save()` is called. This saves all the changes to the on-disk SQLite store.

8.  **Merge to Main Context**: The main `NSManagedObjectContext` (which the UI is connected to) is configured to automatically observe `NSManagedObjectContextDidSave` notifications from the background context. When it receives one, it merges the changes, causing the UI (e.g., a `UITableView` powered by an `NSFetchedResultsController`) to update automatically and display the new data.

## Modernization Plan

This pipeline is already very well-architected. It correctly separates networking, parsing, and persistence, and it uses a background context to avoid blocking the main thread.

-   **Decouple Scraping Logic**: The one major improvement would be to move the individual scraping functions out of the monolithic `ForumsClient.swift` file and into the `AwfulScraping` package. Each set of related scraping functions could live in its own file (e.g., `ForumScraper.swift`, `PostScraper.swift`). This would make the code more modular and easier to maintain. `ForumsClient` would then call these functions, but would no longer contain the implementation details of the scraping itself.

- **HTML Parsing**: The app uses the `HTMLReader` library to parse the HTML document into a traversable DOM tree, similar to browser-based DOM APIs.
- **Data Extraction**: The parsing logic then uses CSS-style selectors (e.g., `table#forum > tr.thread`) to find the relevant HTML elements and extract their contents (e.g., text, attribute values like `href`). The specific scraping logic for each data type (forums, threads, posts, etc.) is currently located in methods within the `ForumsClient` class.
- **Model Object Creation**: The extracted strings and values are used to initialize or update the app's Core Data model objects.

For example, to get a list of threads, the app fetches the HTML for a forum's page. It then finds the main thread list table (`<table id="forum">`), iterates over each thread row (`<tr class="thread">`), and for each row, it finds the cell with the thread title (`<td class="title">`) to extract the thread's name and ID.