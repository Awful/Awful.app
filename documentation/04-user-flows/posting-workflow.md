# Posting Workflow

## Overview

The posting workflow in Awful.app handles creating new posts, replies, and private messages. This system includes rich text editing, preview functionality, and integration with the Something Awful posting system.

## Core Components

### ComposeTextViewController
- **Purpose**: Primary text composition interface
- **Key Features**:
  - Rich text editing with formatting toolbar
  - Preview functionality
  - Draft saving and restoration
  - Smilie integration
  - Image upload support

### Posting System
- **Post Creation**: New thread creation
- **Reply System**: Responding to existing posts
- **Quote Integration**: Quoting previous posts
- **Edit Functionality**: Modifying existing posts

## Workflow Types

### New Post Creation
1. **Thread Selection**: User chooses to create new thread
2. **Form Presentation**: Compose interface appears
3. **Content Creation**: User writes post content
4. **Preview Option**: Optional content preview
5. **Submission**: Post sent to server

### Reply Workflow
1. **Reply Trigger**: User selects reply option
2. **Context Loading**: Original post context loaded
3. **Quote Integration**: Optional quote insertion
4. **Content Creation**: User writes reply
5. **Submission**: Reply sent to server

### Quote and Reply
1. **Text Selection**: User selects text to quote
2. **Quote Formatting**: Selected text formatted as quote
3. **Reply Context**: Original post information included
4. **Content Addition**: User adds response
5. **Submission**: Complete post sent

## User Interface Elements

### Compose Interface
- **Text Editor**: Rich text editing area
- **Formatting Toolbar**: Bold, italic, code, etc.
- **Smilie Button**: Access to custom emoticons
- **Preview Button**: HTML preview of post
- **Submit Button**: Send post to server

### Formatting Options
- **Basic Formatting**: Bold, italic, underline
- **Lists**: Ordered and unordered lists
- **Links**: URL insertion and formatting
- **Images**: Image upload and embedding
- **Code Blocks**: Syntax highlighting

## Rich Text Features

### Formatting System
- **BBCode Support**: Something Awful's markup language
- **HTML Preview**: Real-time preview of formatted content
- **Toolbar Integration**: Quick formatting buttons
- **Keyboard Shortcuts**: Power user shortcuts

### Smilie Integration
- **Custom Keyboard**: Smilie keyboard extension
- **Smilie Picker**: In-app smilie browser
- **Recent Smilies**: Frequently used emoticons
- **Category Browsing**: Organized smilie categories

## Data Management

### Draft System
- **Auto-save**: Periodic draft saving
- **Manual Save**: User-initiated draft storage
- **Draft Recovery**: Restore after app restart
- **Multiple Drafts**: Separate drafts per context

### Post Validation
- **Content Checks**: Ensure post meets requirements
- **Length Limits**: Enforce character/word limits
- **Format Validation**: Check BBCode syntax
- **Image Validation**: Verify uploaded images

## Network Integration

### Posting API
- **Form Submission**: POST request to SA servers
- **Authentication**: Cookie-based session management
- **Error Handling**: Network and server error management
- **Retry Logic**: Automatic retry on failure

### Image Upload
- **Imgur Integration**: Third-party image hosting
- **Upload Progress**: Visual upload indicators
- **Error Handling**: Upload failure management
- **Link Insertion**: Automatic image link insertion

## User Experience Features

### Preview System
- **Live Preview**: Real-time HTML rendering
- **Theme Integration**: Preview with current theme
- **Responsive Preview**: Mobile-optimized display
- **Toggle View**: Switch between edit and preview

### Accessibility
- **VoiceOver Support**: Screen reader compatibility
- **Dynamic Type**: Respect system font sizing
- **Keyboard Navigation**: Full keyboard support
- **Color Contrast**: High contrast mode support

## Error Handling

### Network Errors
- **Connection Failures**: Network unavailability
- **Server Errors**: SA server issues
- **Timeout Handling**: Request timeout management
- **Retry Mechanisms**: Automatic and manual retry

### Validation Errors
- **Content Validation**: Post content requirements
- **Authentication Errors**: Session expiration
- **Permission Errors**: Posting restrictions
- **Format Errors**: BBCode syntax issues

## Migration Considerations

### SwiftUI Conversion
1. **Text Editor**: Replace UITextView with TextEditor
2. **Toolbar**: Convert to SwiftUI toolbar system
3. **Sheets/Modals**: Use SwiftUI presentation system
4. **Navigation**: Update to NavigationView patterns

### Behavioral Preservation
- Maintain exact posting behavior
- Preserve draft management
- Keep formatting capabilities
- Maintain preview accuracy

## Implementation Details

### Key Files
- `ComposeTextViewController.swift`
- `PostPreviewViewController.swift`
- `SmilieKeyboardViewController.swift`
- `ImageUploadManager.swift`
- `PostFormatter.swift`

### Dependencies
- **UITextView**: Rich text editing
- **WKWebView**: Preview rendering
- **Imgur SDK**: Image upload
- **HTMLReader**: HTML parsing
- **Core Data**: Draft persistence

## Testing Scenarios

### Basic Posting
1. Create new post with text content
2. Add formatting and smilies
3. Preview post before submission
4. Submit and verify server response

### Advanced Features
- Quote and reply workflow
- Image upload and embedding
- Draft saving and recovery
- Edit existing post

### Error Scenarios
- Network connection loss during posting
- Server error response handling
- Invalid content validation
- Authentication failure recovery

## Known Issues

### Current Limitations
- Limited rich text formatting options
- Image upload size restrictions
- Preview rendering inconsistencies
- Draft synchronization timing

### Migration Risks
- Text editor behavior changes
- Formatting preservation issues
- Preview system complexity
- Network layer integration