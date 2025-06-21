# Awful App Documentation

This document and all markdown documents in this folder were generated using Google Gemini 2.5 Pro and refined by Claude 4.0 Sonnet inside Cursor IDE, with full access to the repository files.

Documentation generation was done by prompting for each feature individually, requesting that no detail be excluded as a modernization project is being considered. 

As AI becomes more ubiquitous, generating doco on these features as a CI task might be something to consider?

## Project Overview

The Awful app is a client for the Something Awful forums. This codebase has a long history, originating in the early days of iOS, and is built primarily with UIKit and Core Data. It is structured as a main application target with several supporting Swift Packages for modularity.

## Core Architecture

The application's architecture can be broken down into these key areas:

- **Application Entry Point:** `AppDelegate.swift` handles the initial application setup, including creating the main window, setting up the data store, and deciding whether to show the login screen or the main interface.
- **Main UI (Logged In):** The core interface is managed by `RootViewControllerStack.swift`, which sets up a `UISplitViewController`.
    - The `primary` view controller is a `RootTabBarController`, providing tab-based navigation to the app's main sections.
    - The `secondary` view controller is used to display content like forum threads and private messages.
- **Data Layer:**
    - **Networking:** `AwfulCore/ForumsClient.swift` is responsible for all communication with the Something Awful API.
    - **Persistence:** The app uses Core Data to cache forum data, user information, bookmarks, etc. The data store is initialized in the `AppDelegate`.
- **Modularity:** The project is divided into several Swift Packages to separate concerns:
    - `AwfulCore`: Networking and core data models.
    - `AwfulScraping`: HTML parsing logic.
    - `AwfulTheming`: Manages the app's visual themes.
    - `AwfulSettings`: Handles user settings.

## Feature Documentation

Below is a comprehensive list of documents detailing specific features and systems of the application:

### Core Architecture & Infrastructure
- [Application Startup and Initialization](AppStartup.md)
- [Data Persistence & Session Management](Persistence.md)
- [Networking Layer](Networking.md)
- [HTML Scraping & Data Extraction](Scraping.md)
- [Theming System](Theming.md)
- [Background Tasks & Data Refreshing](BackgroundTasks.md)
- [Less & CSS Compilation](Less.md)

### User Interface Features
- [Posts View (WKWebView-based)](PostsView.md)
- [Text Composition System](Composition.md)
- [Context Menus](ContextMenus.md)
- [Settings Screen](Settings.md)

### Main Navigation Tabs
- [Forums View](ForumsView.md)
- [Forum Threads View](ForumThreadsView.md)
- [Bookmarks View](Bookmarks.md)
- [Private Messages View](Messages.md)
- [Leper's Colony View](LepersColony.md)

### Content & Media Features
- [Thread Tags System](ThreadTags.md)
- [Smilies Keyboard & Data](Smilies.md)
- [Embedded Tweets](Tweets.md)
- [Embedded YouTube Videos](YouTube.md)
- [Lottie Animations](Lotties.md)
- [Imgur Integration](Imgur.md)

### Planning & Reference
- [Modernization Candidates](ModernizationCandidates.md)
- [Miscellaneous Technical Debt](Miscellaneous.md)
- [Documentation Template](Template.md) 