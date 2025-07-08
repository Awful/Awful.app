# Private Messages Flow

## Overview

The private messaging system in Awful.app allows users to send and receive private messages through the Something Awful forum system. This flow includes message composition, thread management, and notification handling.

## Core Components

### PrivateMessagesViewController
- **Purpose**: Main private message interface
- **Key Features**:
  - Message thread listing
  - Unread message indicators
  - Message composition
  - Search functionality
  - Folder management

### MessageViewController
- **Purpose**: Individual message display
- **Key Features**:
  - Message content rendering
  - Reply functionality
  - Message metadata
  - Attachment handling

## Message Flow Types

### Inbox Management
1. **Inbox Loading**: Fetch message list from server
2. **Message Selection**: User taps on message thread
3. **Message Display**: Show individual messages
4. **Action Handling**: Reply, delete, or archive

### Compose New Message
1. **Recipient Selection**: Choose message recipient
2. **Subject Entry**: Message subject line
3. **Content Creation**: Write message body
4. **Attachment Options**: Add images or files
5. **Send Process**: Submit message to server

### Reply Workflow
1. **Reply Trigger**: User selects reply option
2. **Context Loading**: Original message loaded
3. **Quote Integration**: Optional quote of original
4. **Content Creation**: User writes reply
5. **Send Process**: Reply sent to server

## User Interface Elements

### Message List
- **Thread View**: Conversation-style message display
- **Unread Indicators**: Bold text for new messages
- **Avatar Display**: Sender profile pictures
- **Timestamp**: Message date and time
- **Search Bar**: Find specific messages

### Message Detail
- **Message Content**: HTML-rendered message body
- **Sender Info**: Profile information and avatar
- **Message Controls**: Reply, delete, archive buttons
- **Attachment Preview**: Inline image/file display

## Data Management

### Message Storage
- **Local Cache**: Core Data storage for messages
- **Sync Strategy**: Server synchronization
- **Offline Access**: Cached message availability
- **Storage Limits**: Message retention policies

### Thread Management
- **Conversation Grouping**: Related messages together
- **Thread Ordering**: Chronological message order
- **Unread Tracking**: Mark read/unread status
- **Archive System**: Message organization

## Notification System

### Push Notifications
- **New Message Alerts**: Immediate notification
- **Badge Updates**: App icon badge count
- **Sound Alerts**: Configurable notification sounds
- **Privacy Settings**: Notification content control

### In-App Notifications
- **Unread Counts**: Message count indicators
- **Visual Indicators**: UI status updates
- **Refresh Triggers**: Automatic content updates
- **Background Sync**: Periodic message checking

## Network Integration

### Message API
- **Fetch Messages**: Retrieve message list
- **Send Messages**: Submit new messages
- **Mark Read**: Update message status
- **Delete Messages**: Remove messages

### Authentication
- **Session Management**: Cookie-based authentication
- **Token Refresh**: Maintain login session
- **Error Handling**: Authentication failures
- **Retry Logic**: Network failure recovery

## User Experience Features

### Message Composition
- **Rich Text Editor**: Formatted message content
- **Smilie Integration**: Custom emoticon support
- **Preview Mode**: Message preview before sending
- **Draft Saving**: Automatic draft preservation

### Search and Filter
- **Message Search**: Find specific content
- **Sender Filter**: Messages from specific users
- **Date Range**: Filter by message date
- **Folder Organization**: Custom message folders

## Accessibility Support

### VoiceOver Features
- **Message Navigation**: Logical reading order
- **Content Description**: Accessible message content
- **Action Labels**: Clear button descriptions
- **Status Announcements**: Unread count updates

### Visual Accessibility
- **Dynamic Type**: Respect system font sizing
- **High Contrast**: Support accessibility themes
- **Color Indicators**: Non-color status indicators
- **Focus Management**: Keyboard navigation

## Error Handling

### Network Errors
- **Connection Failures**: Offline mode handling
- **Server Errors**: SA server issue management
- **Timeout Handling**: Request timeout recovery
- **Retry Mechanisms**: Automatic retry logic

### Message Errors
- **Send Failures**: Message sending errors
- **Validation Errors**: Content validation
- **Permission Errors**: Messaging restrictions
- **Storage Errors**: Local storage issues

## Migration Considerations

### SwiftUI Conversion
1. **List Views**: Replace UITableView with List
2. **Navigation**: Update to NavigationView/Stack
3. **State Management**: Convert to @StateObject patterns
4. **Sheets**: Use SwiftUI presentation system

### Behavioral Preservation
- Maintain exact message display
- Preserve notification behavior
- Keep search functionality
- Maintain offline capabilities

## Implementation Details

### Key Files
- `PrivateMessagesViewController.swift`
- `MessageViewController.swift`
- `MessageComposeViewController.swift`
- `MessageNotificationManager.swift`
- `PrivateMessage.swift` (Core Data model)

### Dependencies
- **Core Data**: Message persistence
- **UserNotifications**: Push notification handling
- **WKWebView**: Message content rendering
- **ForumsClient**: Network communication

## Testing Scenarios

### Basic Messaging
1. Open private message inbox
2. Select and read message
3. Compose and send reply
4. Verify message delivery

### Advanced Features
- Message search functionality
- Notification handling
- Offline message access
- Message attachment handling

### Error Scenarios
- Network connectivity loss
- Message send failures
- Authentication expiration
- Storage capacity issues

## Known Issues

### Current Limitations
- Limited attachment support
- Message size restrictions
- Notification timing delays
- Search performance with large datasets

### Migration Risks
- Notification system changes
- Message rendering complexity
- Network layer integration
- State management complexity