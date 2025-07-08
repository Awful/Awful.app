# Awful.app Documentation

## Overview

This documentation provides comprehensive information about Awful.app, a 20-year-old iOS client for the Something Awful Forums. The documentation is designed to help developers, designers, and AI assistants understand the current implementation and facilitate the modernization effort.

## Purpose

This documentation serves several critical purposes:
- **Preserve Functionality**: Ensure no features are lost during the UIKit to SwiftUI migration
- **Enable Modernization**: Provide clear understanding for updating to iOS 16.1+ and modern APIs
- **Support AI Development**: Comprehensive details for LLMs to assist with development
- **Onboard Contributors**: Help new developers understand this complex legacy codebase

## Documentation Structure

### [01. Getting Started](./01-getting-started/)
Quick start guides, setup instructions, and development environment configuration.

### [02. Architecture](./02-architecture/)
High-level system design, architectural patterns, and component relationships.

### [03. Core Systems](./03-core-systems/)
Detailed documentation of critical systems: authentication, preferences, and data management.

### [04. User Flows](./04-user-flows/)
Comprehensive user journey documentation with custom behaviors unique to Awful.app.

### [05. UI Components](./05-ui-components/)
Current UIKit implementation details and SwiftUI migration considerations.

### [06. Data Layer](./06-data-layer/)
Core Data implementation, models, and persistence strategies.

### [07. Theming](./07-theming/)
Complete theming system documentation including Themes.plist structure.

### [08. Integrations](./08-integrations/)
Third-party services, APIs, and external dependencies.

### [09. Migration Guides](./09-migration-guides/)
Step-by-step guides for migrating from UIKit to SwiftUI.

### [10. Legacy Code](./10-legacy-code/)
Documentation of Objective-C code and technical debt.

### [11. Testing](./11-testing/)
Testing strategies, test coverage, and quality assurance.

### [12. Security](./12-security/)
Security considerations, data privacy, and authentication.

### [13. Troubleshooting](./13-troubleshooting/)
Common issues, debugging techniques, and solutions.

### [14. Reference](./14-reference/)
API documentation, code standards, and quick references.

## Key Areas of Focus

### 🔐 Authentication & Session Management
The app's login system uses cookies for authentication. Understanding this system is critical for maintaining user sessions during the migration.

### 🎨 Theming System
Awful.app features an extensive theming system with forum-specific themes (YOSPOS, FYAD) defined in Themes.plist.

### ⚙️ User Preferences
Preferences are managed through the FOIL package with plist files. Migration to AppStorage is being considered.

### 📱 Custom UI Behaviors
Many UI components have custom behaviors that differ from standard iOS patterns. These must be preserved.

## Contributing to Documentation

When updating documentation:
1. Maintain consistency in formatting and structure
2. Include code examples where relevant
3. Document any assumptions or decisions
4. Update the relevant section's README
5. Consider impact on SwiftUI migration

## Quick Links

- [Setup Guide](./01-getting-started/setup-guide.md)
- [Authentication System](./03-core-systems/authentication.md)
- [Theming Documentation](./07-theming/README.md)
- [UIKit to SwiftUI Migration](./09-migration-guides/uikit-to-swiftui.md)
- [Known Issues](./13-troubleshooting/known-issues.md)
