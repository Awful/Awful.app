# Core Systems Documentation

## Overview

This section documents the critical systems that power Awful.app. These systems must be thoroughly understood for any modernization effort.

## Contents

- [Authentication System](./authentication.md) - Login, cookies, and session management
- [User Preferences](./user-preferences.md) - Settings system and FOIL package
- [Forums Client](./forums-client.md) - Network layer and API client
- [HTML Scraping](./html-scraping.md) - Data extraction from forum pages
- [Core Data Stack](./core-data-stack.md) - Database and persistence layer
- [Error Handling](./error-handling.md) - Error management and recovery
- [Logging System](./logging-system.md) - Debug and diagnostic logging

## Critical Systems

### 🔐 Authentication
The app's login system is cookie-based and determines the user's logged-in state. This system is **critical** - any changes must preserve session management.

### ⚙️ User Preferences  
Managed through the FOIL package with plist files. Consider migration to AppStorage during SwiftUI transition.

### 🌐 Forums Client
The heart of the app - handles all network communication with Something Awful Forums through HTML scraping.

### 💾 Core Data Stack
Complex relational data model that must remain compatible during migration. Background/main context pattern is essential.

## System Dependencies

```
Authentication ──┐
                 ├─→ Forums Client ──→ HTML Scraping ──→ Core Data
User Preferences ──┘
```

## Modernization Notes

During the SwiftUI migration:
- Preserve all authentication behavior
- Consider AppStorage for simple preferences
- Maintain Core Data schema compatibility
- Update error handling to use Result types
- Implement async/await for networking
