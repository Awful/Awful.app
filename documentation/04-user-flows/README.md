# User Flows Documentation

## Overview

This section documents Awful.app's user journeys and custom behaviors that differ from standard iOS patterns. These flows must be preserved exactly during the SwiftUI migration to maintain the app's unique character and functionality.

## Contents

- [App Launch Flow](./app-launch-flow.md) - Initial app startup and authentication
- [Forum Navigation](./forum-navigation.md) - Hierarchical forum browsing
- [Thread Reading](./thread-reading.md) - Post viewing and navigation
- [Posting Workflow](./posting-workflow.md) - Creating posts and replies
- [Private Messages](./private-messages.md) - PM system and notifications
- [Settings and Preferences](./settings-flow.md) - Configuration and customization
- [Theme Switching](./theme-switching.md) - Dynamic theme changes
- [Smilie Keyboard](./smilie-keyboard.md) - Custom keyboard extension
- [Search and Discovery](./search-discovery.md) - Finding content
- [User Profiles](./user-profiles.md) - Viewing user information
- [Custom Gestures](./custom-gestures.md) - Unique interaction patterns

## Critical Custom Behaviors

### 🔄 Thread Page Navigation
- **Swipe gestures** between thread pages
- **Jump to page** functionality
- **Last read position** tracking
- **Infinite scroll** vs. discrete pages

### 👆 Forum-Specific Interactions
- **Long press** menus for threads
- **Pull to refresh** with custom animations
- **Context-sensitive** toolbars
- **Forum-specific** themes and behaviors

### 📱 Custom UI Patterns
- **Slideover** sidebar navigation
- **Toolbar customization** per screen
- **Dynamic** navigation titles
- **State preservation** across app launches

### 🎨 Theming Behaviors
- **Automatic** light/dark switching
- **Forum-specific** theme overrides
- **Real-time** theme updates
- **CSS integration** with native UI

## Flow Categories

### Core Workflows
Essential user journeys that define the app's primary functionality.

### Secondary Workflows
Supporting features that enhance the user experience.

### Edge Cases
Unusual scenarios and error states that require special handling.

### Custom Behaviors
Unique interactions that differ from standard iOS patterns.

## Migration Principles

When converting flows to SwiftUI:

1. **Preserve Behavior**: Maintain exact user experience
2. **Document Differences**: Note any changes from standard patterns
3. **Test Thoroughly**: Verify all edge cases work correctly
4. **Maintain Performance**: Ensure smooth interactions
5. **Respect Accessibility**: Preserve VoiceOver and other accessibility features

## Testing User Flows

For each documented flow:
- Create test scenarios
- Document expected behaviors
- Note error conditions
- Verify accessibility
- Test on different devices
