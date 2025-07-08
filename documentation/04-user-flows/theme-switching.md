# Theme Switching Flow

## Overview

The theme switching system in Awful.app provides dynamic appearance changes that affect both native UI elements and web-rendered content. This system supports light/dark modes, forum-specific themes, and real-time theme updates without requiring app restarts.

## Core Components

### Theme System Architecture
- **Theme Manager**: Central theme coordination
- **Theme Assets**: Color palettes and styling definitions
- **CSS Integration**: Web view styling updates
- **Native UI Updates**: UIKit appearance changes

### Theme Sources
- **System Themes**: Light/dark mode following iOS
- **Custom Themes**: App-specific theme variants
- **Forum Themes**: Per-forum visual customization
- **User Themes**: User-created theme modifications

## Theme Types

### System Integration
- **Automatic**: Follow iOS light/dark mode
- **Light Theme**: Forced light appearance
- **Dark Theme**: Forced dark appearance
- **Dynamic**: Time-based switching

### Forum-Specific Themes
- **YOSPOS**: Special styling for YOSPOS forum
- **FYAD**: Custom colors for FYAD forum
- **Goons With Spoons**: Food forum styling
- **Games**: Gaming forum themes
- **Default**: Standard forum appearance

## Theme Switching Process

### User-Initiated Changes
1. **Settings Access**: User opens theme settings
2. **Theme Selection**: Choose from available themes
3. **Preview Mode**: Optional theme preview
4. **Apply Theme**: Immediate theme activation
5. **Persistence**: Save theme preference

### System-Initiated Changes
1. **iOS Change**: System light/dark mode change
2. **Time-Based**: Automatic switching based on time
3. **Location-Based**: Switching based on sunrise/sunset
4. **App State**: Theme changes on app lifecycle events

## Real-Time Updates

### Native UI Updates
- **Navigation Bars**: Color and tint updates
- **Table Views**: Cell and background colors
- **Buttons**: Tint color updates
- **Status Bar**: Style updates
- **Tab Bar**: Background and tint colors

### Web Content Updates
- **CSS Injection**: Dynamic stylesheet updates
- **Post Rendering**: Re-render with new styles
- **Image Processing**: Theme-aware image filtering
- **Color Scheme**: Web view color scheme updates

## Theme Data Structure

### Theme Definition
```swift
struct Theme {
    let identifier: String
    let displayName: String
    let lightVariant: ThemeColors
    let darkVariant: ThemeColors
    let forumOverrides: [String: ThemeColors]
    let cssStylesheet: String
}
```

### Color Palettes
- **Primary Colors**: Main brand colors
- **Secondary Colors**: Accent and highlight colors
- **Background Colors**: View backgrounds
- **Text Colors**: Primary and secondary text
- **Semantic Colors**: Success, warning, error colors

## Performance Considerations

### Optimization Strategies
- **Lazy Loading**: Load themes on demand
- **Cache Management**: Cache rendered themes
- **Batch Updates**: Group UI updates together
- **Memory Management**: Efficient theme storage

### Update Timing
- **Immediate Updates**: Critical UI elements
- **Deferred Updates**: Non-visible elements
- **Background Updates**: Prepare upcoming themes
- **Progressive Loading**: Gradual theme application

## User Experience Features

### Theme Preview
- **Live Preview**: Real-time theme changes
- **Comparison Mode**: Side-by-side theme comparison
- **Revert Option**: Undo theme changes
- **Theme Gallery**: Browse available themes

### Accessibility Integration
- **High Contrast**: Accessibility theme support
- **Color Blind Support**: Alternative color schemes
- **Reduced Motion**: Minimize transition animations
- **VoiceOver**: Theme change announcements

## Forum-Specific Behavior

### Custom Forum Styling
- **Automatic Detection**: Apply forum-specific themes
- **User Override**: Manual theme selection
- **Theme Inheritance**: Fallback to default themes
- **CSS Customization**: Forum-specific stylesheets

### Theme Persistence
- **Per-Forum Settings**: Remember forum themes
- **Global Override**: User-wide theme preference
- **Session Memory**: Temporary theme changes
- **Sync Across Devices**: Theme preference sync

## Migration Considerations

### SwiftUI Conversion
1. **Environment Values**: Use @Environment for theme data
2. **Color Assets**: Convert to SwiftUI Color system
3. **Appearance Modifiers**: Use SwiftUI appearance modifiers
4. **State Management**: Convert to @StateObject patterns

### Behavioral Preservation
- Maintain exact theme switching timing
- Preserve forum-specific theme behavior
- Keep real-time update performance
- Maintain CSS integration

## Implementation Details

### Key Files
- `ThemeManager.swift`
- `Theme.swift`
- `ThemeColors.swift`
- `AwfulTheming/` package
- `themes.plist`

### Dependencies
- **UIKit**: Native appearance system
- **WKWebView**: Web content styling
- **Core Data**: Theme preference storage
- **Combine**: Reactive theme updates

## CSS Integration

### Stylesheet Management
- **Base Stylesheets**: Core styling definitions
- **Theme Variables**: CSS custom properties
- **Forum Overrides**: Forum-specific styles
- **Dynamic Injection**: Runtime CSS updates

### Web View Updates
- **JavaScript Bridge**: Theme communication
- **CSS Variable Updates**: Dynamic property changes
- **Stylesheet Replacement**: Complete style refresh
- **Caching Strategy**: Efficient style caching

## Testing Scenarios

### Basic Theme Switching
1. Open theme settings
2. Select different theme
3. Verify immediate UI updates
4. Test theme persistence

### Advanced Features
- Forum-specific theme application
- System appearance following
- Real-time CSS updates
- Performance with rapid switching

### Edge Cases
- Theme corruption handling
- Missing theme assets
- Network-dependent theme resources
- Memory pressure scenarios

## Known Issues

### Current Limitations
- CSS injection timing
- Theme asset loading delays
- Memory usage with multiple themes
- Web view update synchronization

### Migration Risks
- SwiftUI appearance system differences
- CSS integration complexity
- Performance regression potential
- Forum-specific behavior preservation