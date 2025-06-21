# Feature: [Feature Name]

**Last Updated:** YYYY-MM-DD

## 1. Summary

A brief, one-paragraph description of what this feature does and its purpose in the app.

## 2. User-Facing Entry Points

How does a user access this feature?

- e.g., "Tapping the 'Forums' tab in the main tab bar."
- e.g., "Selecting 'Bookmarks' from the main tab bar."

## 3. Key Files & Code Components

List the primary classes, storyboards, and files involved in this feature.

- **`SomeViewController.swift`**: Describe its main responsibility.
- **`SomeViewModel.swift`**: Explain its role in managing state or logic.
- **`SomeDataService.swift`**: How it fetches or manipulates data for this feature.
- **`SomeView.storyboard`**: The main UI layout for this feature.

## 4. Data Flow

Explain how data moves through this feature.

- e.g., "1. `ForumsViewController` requests the list of forums from `ForumsClient`. 2. The client fetches HTML from the network. 3. `AwfulScraping` parses the HTML into model objects. 4. The objects are stored in Core Data and passed back to the view controller to be displayed."

## 5. Legacy Code & Modernization Plan

Identify any outdated patterns, known issues, or opportunities for refactoring. This is crucial for your goal of moving to SwiftUI.

- **Pain Points:** "This feature uses a custom delegate pattern that is hard to follow. The layout is managed with manual frame calculations which are brittle."
- **Proposed Changes:** "This entire view could be rewritten in SwiftUI. The view controller logic could be moved into a `StateObject` or `ObservedObject`. The custom navigation could be replaced with a standard `NavigationStack`." 