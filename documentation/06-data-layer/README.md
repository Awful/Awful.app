# Data Layer Documentation

## Overview

Awful.app uses Core Data for persistent storage with a sophisticated data model that has evolved over 20 years. This layer must remain compatible during the SwiftUI migration.

## Contents

- [Core Data Model](./core-data-model.md) - Complete entity relationship diagram
- [Data Flow](./data-flow.md) - How data moves through the system
- [Background Processing](./background-processing.md) - Import and sync operations
- [Context Management](./context-management.md) - Main/background context patterns
- [Entity Relationships](./entity-relationships.md) - Model associations and dependencies
- [Migration Strategy](./migration-strategy.md) - Schema evolution and compatibility
- [Performance Optimization](./performance-optimization.md) - Core Data best practices
- [Offline Support](./offline-support.md) - Local caching strategies

## Core Data Architecture

### Entity Model
```
Forum ───── Thread ───── Post
  │           │          │
  │           │          User
  │           │
  │         ThreadTag
  │
Category
```

### Context Strategy
- **Main Context**: UI binding and user interactions
- **Background Context**: Network imports and heavy processing
- **Private Queue**: Isolated operations

### Key Entities
- **Forum**: Forum categories and subcategories
- **Thread**: Discussion threads with metadata
- **Post**: Individual posts with content and formatting
- **User**: User profiles and authentication state
- **PrivateMessage**: PM system data
- **Announcement**: Forum announcements
- **ThreadTag**: Thread categorization

## Data Persistence Requirements

### Schema Compatibility
- Must maintain existing Core Data schema
- Migration scripts for any schema changes
- Backward compatibility with existing installations

### Performance Requirements
- Smooth scrolling in large thread lists
- Fast search across all content
- Efficient memory usage
- Background sync without blocking UI

### Offline Support
- Complete forum hierarchy caching
- Thread content for offline reading
- Draft composition persistence
- Bookmark synchronization

## Migration Considerations

### Preserve Core Data
- Keep existing entity model unchanged
- Maintain all relationships and constraints
- Preserve data migration paths
- Continue background/main context pattern

### SwiftUI Integration
- Use @FetchRequest for data binding
- Convert NSFetchedResultsController usage
- Maintain observation patterns
- Preserve performance characteristics

### Modernization Opportunities
- Add SwiftData alongside Core Data (future)
- Improve batch operations
- Enhanced error handling
- Better async/await integration
