# Theme Problems

## Overview

This document covers theme system issues, visual problems, and CSS debugging in Awful.app's theming system.

## Theme System Architecture

### Core Components
**Theme Structure**:
- `Theme.plist` - Theme configuration and metadata
- `posts.css` - Main post styling
- `posts-dark.css` - Dark mode variations
- `posts-light.css` - Light mode variations
- Forum-specific CSS files (YOSPOS, FYAD, etc.)

**Key Classes**:
- `Theme` - Theme model object
- `ThemeManager` - Theme loading and management
- `PostsView` - Web view for post rendering
- `LessCompiler` - CSS preprocessing

### Theme Loading Process
1. Load theme plist files
2. Parse theme metadata
3. Compile CSS files with Less.js
4. Cache compiled CSS
5. Apply to web views

## Common Theme Issues

### Theme Not Loading
**Problem**: Custom themes don't appear or load
**Common Causes**:
- Invalid theme plist format
- Missing required files
- Incorrect theme structure
- Parsing errors

**Solutions**:
1. Validate theme plist:
   ```swift
   func validateTheme(_ themeURL: URL) -> Bool {
       guard let plist = NSDictionary(contentsOf: themeURL) else {
           print("❌ Invalid plist format")
           return false
       }
       
       // Check required keys
       let requiredKeys = ["name", "author", "version"]
       for key in requiredKeys {
           if plist[key] == nil {
               print("❌ Missing required key: \(key)")
               return false
           }
       }
       
       return true
   }
   ```

2. Check theme structure:
   ```
   MyTheme.theme/
   ├── Theme.plist
   ├── posts.css
   ├── posts-dark.css (optional)
   └── posts-light.css (optional)
   ```

3. Verify theme installation:
   ```swift
   func listInstalledThemes() {
       let themeManager = ThemeManager.shared
       let themes = themeManager.availableThemes
       
       for theme in themes {
           print("Theme: \(theme.name)")
           print("  Author: \(theme.author)")
           print("  Version: \(theme.version)")
           print("  Files: \(theme.availableFiles)")
       }
   }
   ```

### CSS Compilation Errors
**Problem**: CSS files fail to compile or produce errors
**Common Causes**:
- Invalid Less.js syntax
- Missing variables or mixins
- Circular dependencies
- Syntax errors

**Debugging CSS Compilation**:
1. Enable CSS debug logging:
   ```swift
   UserDefaults.standard.set(true, forKey: "AwfulThemeDebug")
   ```

2. Test CSS compilation:
   ```swift
   func testCSSCompilation(css: String) {
       let compiler = LessCompiler()
       
       do {
           let compiled = try compiler.compile(css)
           print("✅ CSS compiled successfully")
           print("Compiled CSS length: \(compiled.count)")
       } catch {
           print("❌ CSS compilation failed: \(error)")
           
           // Parse error details
           if let compileError = error as? LessCompileError {
               print("Line: \(compileError.line)")
               print("Column: \(compileError.column)")
               print("Message: \(compileError.message)")
           }
       }
   }
   ```

3. Validate CSS syntax:
   ```swift
   func validateCSS(_ css: String) -> [String] {
       var errors = [String]()
       
       // Check for unclosed braces
       let openBraces = css.components(separatedBy: "{").count - 1
       let closeBraces = css.components(separatedBy: "}").count - 1
       if openBraces != closeBraces {
           errors.append("Mismatched braces: \(openBraces) open, \(closeBraces) close")
       }
       
       // Check for invalid selectors
       let selectorPattern = #"[^{}]+\s*\{"#
       let regex = try! NSRegularExpression(pattern: selectorPattern)
       let matches = regex.matches(in: css, range: NSRange(css.startIndex..., in: css))
       
       for match in matches {
           let selector = String(css[Range(match.range, in: css)!])
           if selector.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
               errors.append("Empty selector found")
           }
       }
       
       return errors
   }
   ```

### Visual Display Issues
**Problem**: Theme styles not applying correctly
**Common Causes**:
- CSS specificity issues
- Web view caching
- JavaScript conflicts
- Font loading problems

**Solutions**:
1. Clear web view cache:
   ```swift
   func clearWebViewCache() {
       let websiteDataTypes = NSSet(array: [WKWebsiteDataTypeDiskCache, WKWebsiteDataTypeMemoryCache])
       let date = Date(timeIntervalSince1970: 0)
       
       WKWebsiteDataStore.default().removeData(ofTypes: websiteDataTypes as! Set<String>, modifiedSince: date) {
           print("Web view cache cleared")
       }
   }
   ```

2. Check CSS specificity:
   ```swift
   func debugCSSSpecificity() {
       let webView = postsView.webView
       
       webView.evaluateJavaScript("""
           function getComputedStyle(element, property) {
               return window.getComputedStyle(element).getPropertyValue(property);
           }
           
           // Check if styles are applied
           const post = document.querySelector('.post');
           if (post) {
               console.log('Post background:', getComputedStyle(post, 'background-color'));
               console.log('Post color:', getComputedStyle(post, 'color'));
           }
       """) { result, error in
           if let error = error {
               print("CSS debugging failed: \(error)")
           }
       }
   }
   ```

3. Test theme switching:
   ```swift
   func testThemeSwitch() {
       let themeManager = ThemeManager.shared
       let originalTheme = themeManager.currentTheme
       
       // Switch to different theme
       themeManager.setTheme(named: "Dark")
       
       // Wait for application
       DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
           // Verify theme applied
           let currentTheme = themeManager.currentTheme
           print("Theme switched to: \(currentTheme.name)")
           
           // Switch back
           themeManager.setTheme(originalTheme)
       }
   }
   ```

## Specific Theme Problems

### Dark Mode Issues
**Problem**: Dark mode theme not working correctly
**Common Issues**:
- Incorrect automatic theme switching
- Missing dark mode CSS variants
- System theme detection problems

**Solutions**:
1. Debug dark mode detection:
   ```swift
   func debugDarkMode() {
       let traitCollection = UITraitCollection.current
       let userInterfaceStyle = traitCollection.userInterfaceStyle
       
       print("Current interface style: \(userInterfaceStyle.rawValue)")
       print("Dark mode: \(userInterfaceStyle == .dark)")
       
       // Check theme manager response
       let themeManager = ThemeManager.shared
       let currentTheme = themeManager.currentTheme
       print("Current theme: \(currentTheme.name)")
       print("Theme supports dark mode: \(currentTheme.supportsDarkMode)")
   }
   ```

2. Test automatic theme switching:
   ```swift
   override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
       super.traitCollectionDidChange(previousTraitCollection)
       
       if traitCollection.userInterfaceStyle != previousTraitCollection?.userInterfaceStyle {
           print("Interface style changed to: \(traitCollection.userInterfaceStyle)")
           
           // Update theme
           ThemeManager.shared.updateForUserInterfaceStyle(traitCollection.userInterfaceStyle)
       }
   }
   ```

### Forum-Specific Theme Issues
**Problem**: Special forum themes (YOSPOS, FYAD) not working
**Common Causes**:
- Missing forum-specific CSS files
- Incorrect forum detection
- CSS conflicts with base theme

**Solutions**:
1. Debug forum detection:
   ```swift
   func debugForumTheme(forumID: String) {
       let forum = ForumManager.shared.forum(withID: forumID)
       print("Forum: \(forum?.name ?? "Unknown")")
       print("Forum ID: \(forumID)")
       
       // Check for special theme requirements
       let themeManager = ThemeManager.shared
       let specialTheme = themeManager.specialTheme(for: forumID)
       
       if let specialTheme = specialTheme {
           print("Special theme: \(specialTheme.name)")
       } else {
           print("No special theme for this forum")
       }
   }
   ```

2. Test forum-specific CSS:
   ```swift
   func testForumCSS(forumID: String) {
       let themeManager = ThemeManager.shared
       let css = themeManager.forumSpecificCSS(for: forumID)
       
       if css.isEmpty {
           print("No forum-specific CSS found")
       } else {
           print("Forum CSS length: \(css.count)")
           print("CSS preview: \(css.prefix(200))...")
       }
   }
   ```

### Custom Theme Problems
**Problem**: User-created themes not working
**Common Issues**:
- Invalid theme format
- Missing assets
- Compatibility issues

**Solutions**:
1. Theme validation tool:
   ```swift
   func validateCustomTheme(_ themeURL: URL) -> [String] {
       var issues = [String]()
       
       // Check plist
       let plistURL = themeURL.appendingPathComponent("Theme.plist")
       guard FileManager.default.fileExists(atPath: plistURL.path) else {
           issues.append("Missing Theme.plist")
           return issues
       }
       
       // Validate plist content
       guard let plist = NSDictionary(contentsOf: plistURL) else {
           issues.append("Invalid Theme.plist format")
           return issues
       }
       
       // Check required fields
       let requiredKeys = ["name", "author", "version"]
       for key in requiredKeys {
           if plist[key] == nil {
               issues.append("Missing required key: \(key)")
           }
       }
       
       // Check CSS files
       let cssFiles = ["posts.css"]
       for cssFile in cssFiles {
           let cssURL = themeURL.appendingPathComponent(cssFile)
           if !FileManager.default.fileExists(atPath: cssURL.path) {
               issues.append("Missing CSS file: \(cssFile)")
           }
       }
       
       return issues
   }
   ```

2. CSS preprocessing test:
   ```swift
   func testThemeCSS(_ themeURL: URL) {
       let cssURL = themeURL.appendingPathComponent("posts.css")
       
       do {
           let css = try String(contentsOf: cssURL)
           let compiler = LessCompiler()
           let compiled = try compiler.compile(css)
           
           print("✅ Theme CSS compiled successfully")
           print("Original size: \(css.count) bytes")
           print("Compiled size: \(compiled.count) bytes")
       } catch {
           print("❌ Theme CSS compilation failed: \(error)")
       }
   }
   ```

## Performance Issues

### Slow Theme Loading
**Problem**: Theme switching takes too long
**Common Causes**:
- Large CSS files
- Complex Less.js compilation
- Inefficient caching
- Too many theme variants

**Solutions**:
1. Profile theme loading:
   ```swift
   func profileThemeLoading() {
       let startTime = CFAbsoluteTimeGetCurrent()
       
       ThemeManager.shared.loadTheme(named: "CustomTheme") {
           let endTime = CFAbsoluteTimeGetCurrent()
           let duration = endTime - startTime
           
           print("Theme loaded in \(duration) seconds")
       }
   }
   ```

2. Optimize CSS compilation:
   ```swift
   func optimizeCSS(_ css: String) -> String {
       var optimized = css
       
       // Remove comments
       optimized = optimized.replacingOccurrences(
           of: #"\/\*[\s\S]*?\*\/"#,
           with: "",
           options: .regularExpression
       )
       
       // Remove extra whitespace
       optimized = optimized.replacingOccurrences(
           of: #"\s+"#,
           with: " ",
           options: .regularExpression
       )
       
       // Remove unnecessary semicolons
       optimized = optimized.replacingOccurrences(of: ";}", with: "}")
       
       return optimized
   }
   ```

3. Implement caching:
   ```swift
   class ThemeCache {
       private var cache = NSCache<NSString, NSString>()
       
       func cachedCSS(for theme: Theme) -> String? {
           let key = "\(theme.name)-\(theme.version)" as NSString
           return cache.object(forKey: key) as String?
       }
       
       func setCachedCSS(_ css: String, for theme: Theme) {
           let key = "\(theme.name)-\(theme.version)" as NSString
           cache.setObject(css as NSString, forKey: key)
       }
   }
   ```

### Memory Issues
**Problem**: Theme system consuming too much memory
**Solutions**:
1. Monitor theme memory usage:
   ```swift
   func monitorThemeMemory() {
       let themeManager = ThemeManager.shared
       let loadedThemes = themeManager.loadedThemes
       
       var totalMemory = 0
       for theme in loadedThemes {
           let themeMemory = theme.estimatedMemoryUsage
           totalMemory += themeMemory
           print("Theme \(theme.name): \(themeMemory) bytes")
       }
       
       print("Total theme memory: \(totalMemory) bytes")
   }
   ```

2. Implement theme unloading:
   ```swift
   func unloadUnusedThemes() {
       let themeManager = ThemeManager.shared
       let currentTheme = themeManager.currentTheme
       
       // Unload all themes except current
       for theme in themeManager.loadedThemes {
           if theme != currentTheme {
               themeManager.unloadTheme(theme)
           }
       }
   }
   ```

## Web View Integration Issues

### CSS Injection Problems
**Problem**: Theme CSS not properly injected into web views
**Solutions**:
1. Debug CSS injection:
   ```swift
   func debugCSSInjection(_ webView: WKWebView) {
       webView.evaluateJavaScript("""
           // Check if theme CSS is loaded
           const styleSheets = document.styleSheets;
           let themeFound = false;
           
           for (let i = 0; i < styleSheets.length; i++) {
               try {
                   const sheet = styleSheets[i];
                   if (sheet.href && sheet.href.includes('theme')) {
                       themeFound = true;
                       break;
                   }
               } catch (e) {
                   // Cross-origin restriction
               }
           }
           
           return themeFound;
       """) { result, error in
           if let found = result as? Bool {
               print("Theme CSS found: \(found)")
           } else {
               print("CSS injection check failed: \(error?.localizedDescription ?? "Unknown error")")
           }
       }
   }
   ```

2. Verify CSS application:
   ```swift
   func verifyCSSApplication(_ webView: WKWebView) {
       webView.evaluateJavaScript("""
           // Check computed styles
           const body = document.body;
           const computedStyle = window.getComputedStyle(body);
           
           return {
               backgroundColor: computedStyle.backgroundColor,
               color: computedStyle.color,
               fontFamily: computedStyle.fontFamily
           };
       """) { result, error in
           if let styles = result as? [String: Any] {
               print("Applied styles: \(styles)")
           } else {
               print("Style verification failed: \(error?.localizedDescription ?? "Unknown error")")
           }
       }
   }
   ```

### JavaScript Conflicts
**Problem**: Theme JavaScript conflicts with web view content
**Solutions**:
1. Isolate theme JavaScript:
   ```swift
   func injectThemeScript(_ script: String, into webView: WKWebView) {
       let wrappedScript = """
           (function() {
               try {
                   \(script)
               } catch (error) {
                   console.error('Theme script error:', error);
               }
           })();
       """
       
       webView.evaluateJavaScript(wrappedScript) { _, error in
           if let error = error {
               print("Theme script injection failed: \(error)")
           }
       }
   }
   ```

2. Test JavaScript compatibility:
   ```swift
   func testJavaScriptCompatibility(_ webView: WKWebView) {
       webView.evaluateJavaScript("typeof jQuery !== 'undefined'") { result, error in
           if let hasJQuery = result as? Bool {
               print("jQuery available: \(hasJQuery)")
           }
       }
       
       webView.evaluateJavaScript("typeof window.console !== 'undefined'") { result, error in
           if let hasConsole = result as? Bool {
               print("Console available: \(hasConsole)")
           }
       }
   }
   ```

## Debugging Tools

### Theme Inspector
```swift
class ThemeInspector {
    func inspectTheme(_ theme: Theme) {
        print("=== Theme Inspection ===")
        print("Name: \(theme.name)")
        print("Author: \(theme.author)")
        print("Version: \(theme.version)")
        print("Description: \(theme.description)")
        
        // Check files
        print("\nFiles:")
        for file in theme.files {
            let size = file.size
            print("  \(file.name): \(size) bytes")
        }
        
        // Check CSS
        print("\nCSS Analysis:")
        if let css = theme.compiledCSS {
            let lines = css.components(separatedBy: .newlines).count
            let rules = css.components(separatedBy: "{").count - 1
            print("  Lines: \(lines)")
            print("  Rules: \(rules)")
        }
        
        // Check compatibility
        print("\nCompatibility:")
        print("  Dark mode: \(theme.supportsDarkMode)")
        print("  Light mode: \(theme.supportsLightMode)")
    }
}
```

### CSS Analyzer
```swift
class CSSAnalyzer {
    func analyzeCSS(_ css: String) -> CSSAnalysis {
        var analysis = CSSAnalysis()
        
        // Count selectors
        let selectorPattern = #"[^{}]+(?=\s*\{)"#
        let selectorRegex = try! NSRegularExpression(pattern: selectorPattern)
        analysis.selectorCount = selectorRegex.numberOfMatches(in: css, range: NSRange(css.startIndex..., in: css))
        
        // Count properties
        let propertyPattern = #"[^{}:;]+\s*:\s*[^{}:;]+\s*;"#
        let propertyRegex = try! NSRegularExpression(pattern: propertyPattern)
        analysis.propertyCount = propertyRegex.numberOfMatches(in: css, range: NSRange(css.startIndex..., in: css))
        
        // Check for common issues
        if css.contains("!important") {
            analysis.warnings.append("Uses !important declarations")
        }
        
        if css.contains("*") {
            analysis.warnings.append("Uses universal selector")
        }
        
        return analysis
    }
}

struct CSSAnalysis {
    var selectorCount = 0
    var propertyCount = 0
    var warnings = [String]()
}
```

## Recovery and Repair

### Theme Recovery
```swift
func recoverThemes() {
    let themeManager = ThemeManager.shared
    
    // Reset to default theme
    themeManager.setTheme(ThemeManager.defaultTheme)
    
    // Clear theme cache
    themeManager.clearCache()
    
    // Reload themes
    themeManager.reloadThemes()
    
    print("Theme system recovered")
}
```

### CSS Repair
```swift
func repairCSS(_ css: String) -> String {
    var repaired = css
    
    // Fix common syntax errors
    repaired = repaired.replacingOccurrences(of: ";;", with: ";")
    repaired = repaired.replacingOccurrences(of: "{{", with: "{")
    repaired = repaired.replacingOccurrences(of: "}}", with: "}")
    
    // Remove invalid characters
    repaired = repaired.replacingOccurrences(
        of: #"[^\x20-\x7E\n\r\t]"#,
        with: "",
        options: .regularExpression
    )
    
    return repaired
}
```

## Best Practices

### Theme Development
1. **Validation**: Always validate theme files before distribution
2. **Testing**: Test themes in different modes and configurations
3. **Documentation**: Document theme features and requirements
4. **Versioning**: Use semantic versioning for theme updates
5. **Compatibility**: Ensure backward compatibility when possible

### Performance Optimization
1. **Minimize CSS**: Remove unnecessary styles and comments
2. **Optimize Assets**: Compress images and resources
3. **Cache Wisely**: Implement intelligent caching strategies
4. **Load Efficiently**: Use lazy loading for theme resources
5. **Profile Regularly**: Monitor theme performance impact

### Error Handling
1. **Graceful Degradation**: Provide fallbacks for missing themes
2. **User Feedback**: Inform users about theme issues
3. **Logging**: Comprehensive logging for debugging
4. **Recovery**: Implement automatic recovery mechanisms
5. **Validation**: Validate all theme inputs and configurations