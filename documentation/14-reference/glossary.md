# Glossary

Comprehensive glossary of terms, concepts, and definitions specific to Awful.app and forum development.

## Table of Contents

- [General Terms](#general-terms)
- [Architecture Terms](#architecture-terms)
- [Core Data Terms](#core-data-terms)
- [UI/UX Terms](#uiux-terms)
- [Networking Terms](#networking-terms)
- [Something Awful Forums Terms](#something-awful-forums-terms)
- [Build and Development Terms](#build-and-development-terms)
- [Testing Terms](#testing-terms)
- [Security Terms](#security-terms)

## General Terms

### API (Application Programming Interface)
A set of protocols, routines, and tools for building software applications. In Awful.app, refers to the interface between the app and Something Awful Forums.

### Async/Await
Modern Swift concurrency pattern used throughout Awful.app for handling asynchronous operations like network requests and Core Data operations.

### BBCode
Bulletin Board Code - a lightweight markup language used in forum posts to format text. Examples: `[b]bold[/b]`, `[url]link[/url]`, `[img]image[/img]`.

### Bundle Identifier
Unique identifier for iOS apps, typically in reverse DNS format (e.g., `com.awfulapp.Awful`).

### Closure
Swift programming construct that captures and stores references to variables and constants from the surrounding context.

### Delegate Pattern
Design pattern where one object acts on behalf of another object, commonly used in UIKit for handling events and customization.

### Extension
Swift feature that adds functionality to existing classes, structures, enumerations, or protocols.

### Framework
Collection of code that provides specific functionality. Awful.app uses both system frameworks (UIKit, Core Data) and third-party frameworks (Nuke, HTMLReader).

### Property Wrapper
Swift feature that wraps property access with custom logic. Awful.app uses `@FoilDefaultStorage` for UserDefaults access.

### Swift Package Manager (SPM)
Apple's dependency manager for Swift packages, used extensively in Awful.app's modular architecture.

## Architecture Terms

### MVVM (Model-View-ViewModel)
Architectural pattern used in SwiftUI portions of Awful.app, separating data (Model), presentation (View), and business logic (ViewModel).

### MVC (Model-View-Controller)
Primary architectural pattern in Awful.app's UIKit components, separating data models, user interface, and coordination logic.

### Coordinator Pattern
Navigation pattern used in Awful.app to decouple view controllers from navigation logic, making flows more testable and reusable.

### Repository Pattern
Data access pattern that abstracts the data layer, providing a uniform interface for data operations regardless of the underlying storage mechanism.

### Dependency Injection
Design pattern where dependencies are provided to an object rather than created internally, improving testability and modularity.

### Observer Pattern
Pattern where objects notify observers of state changes. Used extensively in Awful.app through Core Data notifications and Combine publishers.

### Singleton Pattern
Design pattern ensuring a class has only one instance. Used sparingly in Awful.app for truly global state like `ForumsClient.shared`.

### Strategy Pattern
Pattern for selecting algorithms at runtime. Used in Awful.app for different refresh strategies and theme selection.

## Core Data Terms

### Managed Object Context
Environment where Core Data objects exist and are managed. Awful.app uses separate contexts for main thread (UI) and background operations.

### Managed Object Model
Schema describing the structure of Core Data entities, attributes, and relationships, defined in `.xcdatamodeld` files.

### Persistent Store Coordinator
Core Data component that manages the persistent stores and provides contexts with access to the data.

### Fetch Request
Query object used to retrieve data from Core Data stores, similar to SQL SELECT statements.

### Fetched Results Controller
Core Data class that efficiently manages the results of a fetch request and provides automatic change notifications for table/collection views.

### Entity
Core Data equivalent of a database table, representing a type of object that can be stored (e.g., User, Thread, Post).

### Relationship
Connection between Core Data entities, either one-to-one, one-to-many, or many-to-many.

### Faulting
Core Data's lazy loading mechanism where object data is not loaded until actually accessed, improving memory efficiency.

### Migration
Process of updating Core Data model versions while preserving existing data.

## UI/UX Terms

### Auto Layout
iOS layout system using constraints to define relationships between UI elements, ensuring proper layout across different screen sizes.

### Collection View
UIKit component for displaying ordered collections of data items in customizable layouts.

### Table View
UIKit component for displaying data in a single-column list with sections and rows.

### Navigation Controller
UIKit component that manages a stack of view controllers with built-in navigation UI.

### Storyboard
Visual interface design tool in Xcode for laying out app screens and their connections.

### XIB (Xcode Interface Builder)
Individual interface files for designing custom views and view controllers.

### Constraint
Auto Layout rule defining the relationship between UI elements (e.g., spacing, alignment, size).

### Safe Area
iOS UI area that avoids system UI elements like the status bar, home indicator, and notch.

### Trait Collection
Object describing the current environment for UI elements, including size class, display scale, and user interface idiom.

### Segue
Storyboard connection between view controllers that defines a transition.

## Networking Terms

### URLSession
Foundation framework for making HTTP requests and handling responses.

### HTTP Cookie
Small data stored by web browsers, used in Awful.app to maintain forum login sessions.

### JSON (JavaScript Object Notation)
Lightweight data interchange format used for some API responses.

### HTML Scraping
Process of extracting structured data from HTML pages, used extensively since Something Awful Forums lacks a formal API.

### Base64 Encoding
Method of encoding binary data into ASCII text, used for image uploads and authentication.

### Cache
Temporary storage of data to improve performance and reduce network requests.

### Timeout
Maximum time allowed for a network operation before it's considered failed.

### SSL/TLS
Encryption protocols for secure network communication (HTTPS).

### User Agent
String identifying the client software making HTTP requests.

### Request/Response
HTTP communication pattern where clients send requests and servers send back responses.

## Something Awful Forums Terms

### Awful Thread
Core forum concept representing a discussion topic with multiple posts. Prefixed with "Awful" to avoid naming conflicts with Foundation's Thread class.

### Post
Individual message within a thread, containing user content, timestamp, and metadata.

### Forum
Category or section containing related threads (e.g., General Bullshit, FYAD, YOSPOS).

### Thread Tag
Icon associated with threads to indicate topic, status, or category.

### Secondary Thread Tag
Additional smaller icon that can accompany the main thread tag.

### Smilie
Custom emoticon used in forum posts, managed by the Smilies package.

### Private Message
Direct message between forum users, separate from public thread posts.

### Bookmark
User's saved list of interesting threads for easy access.

### Star Category
Color-coded bookmark categories (Orange, Red, Yellow, Green, Blue, Purple).

### Announcement
Special posts from moderators/administrators shown at the top of forum lists.

### Ignore List
User's list of other users whose posts should be hidden.

### Leper's Colony
Forum's ban/punishment tracking system, showing user infractions.

### Platinum Member
Premium forum account status with additional features.

### Goon
Colloquial term for Something Awful Forums member.

### SA Forums
Abbreviation for Something Awful Forums.

### FYAD
"F*** You And Die" - specific forum section with unique theming.

### YOSPOS
"Your Opinions Suck, Post Other Stuff" - forum section with terminal-style theming.

### BYOB
"Bring Your Own Blog" - forum section for personal updates.

### Gas Chamber
Controversial forum section (archive only).

### Post Index
Position of a post within a thread, starting from 0.

### Thread Index
Position of a thread within a forum listing.

### Seen Posts
Number of posts a user has read in a thread.

### Last Post Date
Timestamp of the most recent post in a thread.

## Build and Development Terms

### Xcode
Apple's integrated development environment (IDE) for iOS, macOS, and other Apple platform development.

### Build Configuration
Set of build settings for different purposes (Debug, Release, etc.).

### Scheme
Collection of targets to build, configuration to use, and tests to run.

### Target
Specific product to build from source code (app, extension, framework, etc.).

### Bundle
Directory containing executable code and resources for an app or framework.

### Provisioning Profile
Certificate allowing apps to run on specific devices or be distributed through the App Store.

### Code Signing
Process of digitally signing code to verify its authenticity and integrity.

### Entitlements
Special permissions an app requests from the system (e.g., App Groups, Keychain access).

### App Group
Shared container allowing multiple related apps to share data.

### Derived Data
Xcode-generated build products, indexes, and logs.

### Archive
Packaged app ready for distribution or App Store submission.

### TestFlight
Apple's beta testing service for distributing pre-release app versions.

### App Store Connect
Apple's portal for managing app distribution, analytics, and metadata.

### Configuration File (.xcconfig)
Text file containing build settings that can be shared across targets and projects.

### Info.plist
Property list file containing app metadata and configuration.

### Launch Screen
First screen users see when launching an app, while the app loads.

## Testing Terms

### Unit Test
Test that verifies the behavior of individual components in isolation.

### Integration Test
Test that verifies the interaction between multiple components.

### UI Test
Automated test that interacts with the app's user interface.

### Test Plan
Configuration defining which tests to run and under what conditions.

### Test Target
Xcode target containing test code for a specific module or feature.

### Mock Object
Fake object that simulates the behavior of real objects for testing purposes.

### Fixture
Predefined data used in tests to ensure consistent test conditions.

### Assertion
Statement in test code that verifies expected behavior or state.

### Test Coverage
Measure of how much code is executed during testing.

### Continuous Integration (CI)
Practice of automatically building and testing code changes.

### XCTest
Apple's testing framework for unit, integration, and UI tests.

### Test Case
Individual test method that verifies specific functionality.

### Test Suite
Collection of related test cases.

## Security Terms

### Keychain
Secure storage system for sensitive data like passwords and certificates.

### App Transport Security (ATS)
iOS security feature requiring secure network connections by default.

### Code Signing Identity
Certificate used to sign code, proving the developer's identity.

### Certificate
Digital document verifying the identity of a person or organization.

### Private Key
Secret key used for encryption and digital signatures.

### Public Key
Publicly shareable key used for encryption and signature verification.

### SSL Pinning
Security technique that validates server certificates against known good certificates.

### Data Protection
iOS feature that encrypts user data when the device is locked.

### Secure Enclave
Hardware security module in iOS devices for storing sensitive data.

### Touch ID / Face ID
Biometric authentication systems integrated with iOS apps.

### Two-Factor Authentication (2FA)
Security method requiring two forms of verification for account access.

---

## Acronyms and Abbreviations

| Acronym | Full Form | Context |
|---------|-----------|---------|
| API | Application Programming Interface | General development |
| ARC | Automatic Reference Counting | Memory management |
| ATS | App Transport Security | iOS security |
| BYOB | Bring Your Own Blog | SA Forums section |
| CI | Continuous Integration | Development workflow |
| CSS | Cascading Style Sheets | Web styling |
| FYAD | F*** You And Die | SA Forums section |
| GCD | Grand Central Dispatch | Concurrency |
| HTML | HyperText Markup Language | Web content |
| HTTP | HyperText Transfer Protocol | Networking |
| HTTPS | HTTP Secure | Secure networking |
| IDE | Integrated Development Environment | Development tools |
| JSON | JavaScript Object Notation | Data format |
| MVC | Model-View-Controller | Architecture pattern |
| MVVM | Model-View-ViewModel | Architecture pattern |
| REST | Representational State Transfer | API design |
| SA | Something Awful | Forum website |
| SDK | Software Development Kit | Development tools |
| SPM | Swift Package Manager | Dependency management |
| SQL | Structured Query Language | Database queries |
| SSL | Secure Sockets Layer | Network security |
| TLS | Transport Layer Security | Network security |
| UI | User Interface | App presentation |
| URL | Uniform Resource Locator | Web addresses |
| UX | User Experience | App usability |
| XIB | XML Interface Builder | Interface files |
| YOSPOS | Your Opinions Suck, Post Other Stuff | SA Forums section |

This glossary serves as a comprehensive reference for understanding the terminology used throughout the Awful.app project, helping developers quickly understand concepts and communicate effectively about the codebase.