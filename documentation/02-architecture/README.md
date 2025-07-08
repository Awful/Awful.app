# Architecture Documentation

## Overview

This section provides comprehensive documentation of Awful.app's architecture, from high-level design patterns to detailed component interactions.

## Contents

- [System Overview](./system-overview.md) - High-level architecture and component relationships
- [Design Patterns](./design-patterns.md) - Architectural patterns and their implementation
- [Data Flow](./data-flow.md) - How data moves through the system
- [Module Structure](./module-structure.md) - Package organization and dependencies
- [Networking Layer](./networking-layer.md) - API client and HTML scraping architecture
- [Persistence Layer](./persistence-layer.md) - Core Data implementation details
- [UI Architecture](./ui-architecture.md) - UIKit structure and SwiftUI migration plan

## Key Architectural Decisions

### HTML Scraping vs API
- **Decision**: Use HTML scraping instead of official API
- **Reason**: Something Awful has no public API
- **Implementation**: Custom HTMLReader-based scraping
- **Trade-offs**: Fragile but flexible

### Core Data for Persistence
- **Decision**: Use Core Data for local storage
- **Reason**: Complex relational data, offline support
- **Implementation**: Background/main context pattern
- **Trade-offs**: Complexity vs powerful features

### UIKit to SwiftUI Migration
- **Decision**: Gradual migration to SwiftUI
- **Reason**: Modernization while preserving functionality
- **Implementation**: Hybrid approach with UIViewControllerRepresentable
- **Trade-offs**: Temporary complexity for long-term benefits

## Architecture Principles

1. **Separation of Concerns**: Clear boundaries between UI, business logic, and data
2. **Offline First**: Cache everything, sync when possible
3. **Performance**: Smooth scrolling and fast loading
4. **Maintainability**: Code should be understandable and modifiable
5. **Testability**: Components should be testable in isolation

## Migration Strategy

As we modernize the architecture:
- Preserve Core Data schema compatibility
- Maintain existing API contracts
- Introduce SwiftUI views gradually
- Use modern concurrency patterns
- Improve error handling and logging
