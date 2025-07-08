# Theming System Documentation

## Overview

Awful.app features one of the most sophisticated theming systems in iOS development, with support for:
- **Forum-specific themes** (YOSPOS, FYAD, etc.)
- **Automatic light/dark mode switching**
- **CSS integration with native UI**
- **Real-time theme updates**
- **Hierarchical theme inheritance**

This documentation is **critical** for the SwiftUI migration as the theming system must be fully replicated.

## Contents

- [Theme Architecture](./theme-architecture.md) - Overall system design
- [Themes.plist Structure](./themes-plist.md) - Complete plist documentation
- [CSS Integration](./css-integration.md) - How CSS works with native UI
- [Forum-Specific Themes](./forum-themes.md) - YOSPOS, FYAD, and custom themes
- [Theme Application](./theme-application.md) - How themes are applied to UI
- [Less Stylesheet System](./less-stylesheets.md) - Dynamic CSS compilation
- [SwiftUI Migration](./swiftui-theming.md) - Converting themes to SwiftUI
- [Creating New Themes](./creating-themes.md) - Designer guide for new themes

## Quick Reference

### Theme Files
- **Themes.plist**: `AwfulTheming/Sources/AwfulTheming/Themes.plist`
- **CSS Templates**: `App/Resources/Templates/`
- **Less Files**: `LessStylesheet/Sources/`

### Key Classes
- **Theme**: Core theme object
- **ThemeManager**: Theme application and switching
- **LessStylesheetLoader**: CSS compilation
- **Themeable Protocol**: UI component theming

## Theme Categories

### Base Themes
- **light**: Default light theme
- **dark**: Default dark theme
- **oled**: True black theme for OLED devices

### Forum-Specific Themes
- **yospos**: You Only Screenshot Posts Once theme
- **fyad**: F*** You and Die theme  
- **byob**: Build Your Own Bomb theme
- **games**: Games forum theme

### Special Themes
- **winpos95**: Windows 95 retro theme
- **macinyos**: Mac OS classic theme
- **green-amber**: Terminal/Matrix theme

## Critical Features

### 🎨 Real-Time Updates
Themes update immediately across all UI components without requiring app restart.

### 🌙 Automatic Mode Switching
Themes automatically switch between light and dark variants based on system appearance.

### 🏰 Forum Context
Themes can be overridden per forum, creating unique experiences for different communities.

### 📝 CSS Integration
Native UI elements use CSS values for consistent styling between web content and native components.

## SwiftUI Migration Priority

The theming system is **high priority** for SwiftUI migration because:
1. Custom themes are a defining feature of Awful.app
2. Users rely on forum-specific theming
3. CSS integration affects post rendering
4. Real-time updates are expected behavior

## For Designers

See [Creating New Themes](./creating-themes.md) for:
- Color palette guidelines
- Typography specifications
- CSS template usage
- Testing procedures
