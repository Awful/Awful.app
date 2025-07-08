# Core Data Model

## Overview

Awful.app's Core Data model has evolved over 20+ years to support the complex data structures of Something Awful Forums. The model includes forums, threads, posts, users, private messages, and various metadata entities.

## Entity Relationship Diagram

```
                    Category
                       │
                   ┌───▼───┐
                   │ Forum │
                   └───┬───┘
                       │
                   ┌───▼────┐     ┌─────────┐
                   │ Thread │◄────┤ThreadTag│
                   └───┬────┘     └─────────┘
                       │
                   ┌───▼───┐
                   │ Post  │
                   └───┬───┘
                       │
                   ┌───▼───┐
                   │ User  │
                   └───┬───┘
                       │
              ┌────────┴─────────┐
              │                  │
        ┌─────▼──────┐    ┌──────▼──────┐
        │PrivateMsg  │    │ Announcement│
        └────────────┘    └─────────────┘
```

## Core Entities

### Forum
- **Purpose**: Represents forum categories and individual forums
- **Key Attributes**:
  - `forumID`: Unique forum identifier
  - `name`: Forum display name
  - `forumDescription`: Forum description text
  - `category`: Parent category (optional)
  - `parentForum`: Parent forum for hierarchy
  - `childForums`: Child forums
  - `threads`: Collection of threads in forum
  - `canPost`: User posting permissions
  - `isBookmarked`: User bookmark status

**Relationships**:
- One-to-many with Thread
- Many-to-one with Category
- Self-referencing for forum hierarchy
- Many-to-many with User (bookmarks)

### Thread
- **Purpose**: Discussion threads within forums
- **Key Attributes**:
  - `threadID`: Unique thread identifier
  - `title`: Thread title
  - `author`: Thread creator
  - `authorUserID`: Creator's user ID
  - `forum`: Parent forum
  - `posts`: Collection of posts
  - `numberOfPages`: Total page count
  - `numberOfPosts`: Total post count
  - `totalUnreadPosts`: Unread post count
  - `isBookmarked`: User bookmark status
  - `isLocked`: Thread lock status
  - `isSticky`: Sticky thread flag
  - `threadTag`: Thread categorization tag
  - `lastPostAuthorName`: Last post author
  - `lastPostDate`: Last post timestamp
  - `seenPosts`: User's read progress

**Relationships**:
- Many-to-one with Forum
- One-to-many with Post
- Many-to-one with ThreadTag
- Many-to-one with User (author)
- Many-to-many with User (bookmarks)

### Post
- **Purpose**: Individual posts within threads
- **Key Attributes**:
  - `postID`: Unique post identifier
  - `thread`: Parent thread
  - `author`: Post author
  - `authorUserID`: Author's user ID
  - `postDate`: Post creation date
  - `innerHTML`: Post HTML content
  - `text`: Plain text content
  - `attachments`: File attachments
  - `editedDate`: Last edit timestamp
  - `editedBy`: Editor information
  - `postIndex`: Position in thread

**Relationships**:
- Many-to-one with Thread
- Many-to-one with User (author)
- One-to-many with Attachment (if implemented)

### User
- **Purpose**: Forum user profiles and metadata
- **Key Attributes**:
  - `userID`: Unique user identifier
  - `username`: Display username
  - `customTitleHTML`: Custom user title
  - `avatarURL`: Profile avatar URL
  - `regdate`: Registration date
  - `postCount`: Total posts made
  - `postRate`: Posts per day
  - `lastPost`: Last post timestamp
  - `location`: User location
  - `interests`: User interests
  - `occupation`: User occupation
  - `contactInfo`: Contact information
  - `administrator`: Admin status
  - `moderator`: Moderator status
  - `authorClasses`: CSS classes for styling

**Relationships**:
- One-to-many with Post (authored posts)
- One-to-many with Thread (created threads)
- One-to-many with PrivateMessage (sent/received)
- Many-to-many with Forum (bookmarked forums)
- Many-to-many with Thread (bookmarked threads)

### PrivateMessage
- **Purpose**: Private message system
- **Key Attributes**:
  - `messageID`: Unique message identifier
  - `subject`: Message subject
  - `innerHTML`: Message HTML content
  - `text`: Plain text content
  - `sentDate`: Message send date
  - `seen`: Read status
  - `forwarded`: Forward status
  - `replied`: Reply status
  - `sender`: Message sender
  - `recipient`: Message recipient
  - `senderUserID`: Sender's user ID
  - `recipientUserID`: Recipient's user ID

**Relationships**:
- Many-to-one with User (sender)
- Many-to-one with User (recipient)
- One-to-many with self (reply chains)

### ThreadTag
- **Purpose**: Thread categorization and visual indicators
- **Key Attributes**:
  - `threadTagID`: Unique tag identifier
  - `imageName`: Tag image filename
  - `name`: Tag display name
  - `explanation`: Tag description
  - `threadTagURL`: Tag image URL

**Relationships**:
- One-to-many with Thread

### Announcement
- **Purpose**: Forum announcements and notices
- **Key Attributes**:
  - `announcementID`: Unique announcement identifier
  - `title`: Announcement title
  - `bodyHTML`: Announcement content
  - `postedDate`: Publication date
  - `author`: Announcement author
  - `hasBeenSeen`: User view status

**Relationships**:
- Many-to-one with User (author)

## Data Types and Constraints

### String Attributes
- **Text Fields**: Variable length strings for content
- **HTML Fields**: Rich text content with markup
- **URL Fields**: Validated URL strings
- **Identifier Fields**: Unique string identifiers

### Numeric Attributes
- **ID Fields**: Integer identifiers (Int64)
- **Count Fields**: Post counts, page counts (Int32)
- **Boolean Fields**: Status flags (Bool)
- **Decimal Fields**: Numeric calculations (Decimal)

### Date Attributes
- **Timestamp Fields**: NSDate for all temporal data
- **Optional Dates**: Nullable date fields
- **Derived Dates**: Calculated date values

### Relationship Constraints
- **Delete Rules**: Cascade, nullify, or deny
- **Inverse Relationships**: Bidirectional consistency
- **Optional Relationships**: Nullable foreign keys
- **Ordered Relationships**: Maintained collection order

## Core Data Configuration

### Persistent Store Setup
```swift
// Core Data Stack Configuration
lazy var persistentContainer: NSPersistentContainer = {
    let container = NSPersistentContainer(name: "AwfulData")
    container.loadPersistentStores { _, error in
        if let error = error {
            fatalError("Core Data error: \(error)")
        }
    }
    return container
}()
```

### Context Configuration
```swift
// Main Context - UI Thread
var mainContext: NSManagedObjectContext {
    return persistentContainer.viewContext
}

// Background Context - Import Operations
var backgroundContext: NSManagedObjectContext {
    return persistentContainer.newBackgroundContext()
}
```

### Fetch Request Optimization
```swift
// Optimized Forum Fetch
let forumRequest: NSFetchRequest<Forum> = Forum.fetchRequest()
forumRequest.predicate = NSPredicate(format: "parentForum == nil")
forumRequest.sortDescriptors = [NSSortDescriptor(key: "index", ascending: true)]
forumRequest.relationshipKeyPathsForPrefetching = ["childForums"]
```

## Data Validation

### Entity Validation
- **Required Fields**: Non-nullable attributes
- **Format Validation**: URL and email validation
- **Range Validation**: Numeric range constraints
- **Custom Validation**: Business logic validation

### Relationship Validation
- **Referential Integrity**: Foreign key constraints
- **Orphan Prevention**: Cascade delete rules
- **Circular Reference**: Prevention mechanisms
- **Consistency Checks**: Data integrity validation

## Performance Optimizations

### Fetch Optimization
- **Batch Fetching**: Reduce database roundtrips
- **Prefetching**: Load related objects efficiently
- **Faulting**: Lazy loading of large objects
- **Result Limits**: Pagination for large datasets

### Memory Management
- **Fault Management**: Control object faulting
- **Cache Management**: Managed object cache
- **Batch Processing**: Efficient bulk operations
- **Memory Pressure**: Handle memory warnings

### Index Strategy
- **Primary Indexes**: ID field indexing
- **Search Indexes**: Text search optimization
- **Composite Indexes**: Multi-field queries
- **Unique Constraints**: Data uniqueness enforcement

## Migration Considerations

### Schema Evolution
- **Lightweight Migration**: Automatic schema updates
- **Heavy Migration**: Custom migration logic
- **Version Management**: Schema version tracking
- **Backward Compatibility**: Support older versions

### Data Preservation
- **Migration Scripts**: Custom data transformation
- **Validation Scripts**: Post-migration verification
- **Rollback Strategy**: Migration failure recovery
- **Performance Testing**: Migration performance validation

## SwiftUI Integration

### @FetchRequest Usage
```swift
// SwiftUI Fetch Request
@FetchRequest(
    entity: Thread.entity(),
    sortDescriptors: [NSSortDescriptor(key: "lastPostDate", ascending: false)],
    predicate: NSPredicate(format: "forum == %@", forum)
) var threads: FetchedResults<Thread>
```

### ObservableObject Patterns
```swift
// View Model with Core Data
class ThreadListViewModel: ObservableObject {
    @Published var threads: [Thread] = []
    private let context: NSManagedObjectContext
    
    func loadThreads(for forum: Forum) {
        // Core Data fetch implementation
    }
}
```

## Testing Strategies

### Unit Testing
- **Model Testing**: Entity creation and validation
- **Relationship Testing**: Association verification
- **Migration Testing**: Schema evolution verification
- **Performance Testing**: Query performance measurement

### Integration Testing
- **Data Flow Testing**: End-to-end data operations
- **Sync Testing**: Network data synchronization
- **Offline Testing**: Local data operations
- **Error Handling**: Data error scenarios

## Known Issues and Limitations

### Current Limitations
- **Large Dataset Performance**: Memory usage with large forums
- **Search Performance**: Full-text search limitations
- **Relationship Complexity**: Complex query performance
- **Migration Complexity**: Schema evolution challenges

### Workaround Strategies
- **Pagination**: Limit data loading
- **Background Processing**: Off-main-thread operations
- **Cache Management**: Intelligent data caching
- **Query Optimization**: Efficient fetch requests