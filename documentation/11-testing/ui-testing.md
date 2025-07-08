# UI Testing

## Overview

UI testing in Awful.app focuses on user interface automation, visual validation, and end-to-end user experience testing. This document covers strategies for testing both UIKit and SwiftUI components, automation patterns, and visual regression testing.

## UI Testing Framework

### XCUITest Foundation

#### Basic Setup
```swift
import XCTest

final class AwfulUITests: XCTestCase {
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app.terminate()
        app = nil
    }
}
```

#### Test Configuration
```swift
extension XCUIApplication {
    func launchForTesting() {
        launchArguments = [
            "--uitesting",
            "--reset-user-defaults",
            "--disable-animations",
            "--use-test-data"
        ]
        launchEnvironment = [
            "UITEST_MODE": "1",
            "NETWORK_DELAY_MS": "100"
        ]
        launch()
    }
}
```

## Core UI Test Patterns

### Navigation Testing

#### Tab Bar Navigation
```swift
func testTabBarNavigation() {
    // Test all main tabs
    let tabBar = app.tabBars.firstMatch
    
    // Forums tab
    tabBar.buttons["Forums"].tap()
    XCTAssertTrue(app.navigationBars["Forums"].exists)
    
    // Bookmarks tab
    tabBar.buttons["Bookmarks"].tap()
    XCTAssertTrue(app.navigationBars["Bookmarks"].exists)
    
    // Messages tab
    tabBar.buttons["Messages"].tap()
    XCTAssertTrue(app.navigationBars["Messages"].exists)
    
    // Settings tab
    tabBar.buttons["Settings"].tap()
    XCTAssertTrue(app.navigationBars["Settings"].exists)
}
```

#### Navigation Stack Testing
```swift
func testForumNavigationStack() {
    // Navigate to forums
    app.tabBars.buttons["Forums"].tap()
    
    // Select a forum category
    let forumsTable = app.tables.firstMatch
    forumsTable.cells.element(boundBy: 0).tap()
    
    // Verify forum list
    XCTAssertTrue(app.navigationBars.buttons["Forums"].exists)
    
    // Select a specific forum
    forumsTable.cells.element(boundBy: 0).tap()
    
    // Verify thread list
    XCTAssertTrue(app.navigationBars.buttons.element(boundBy: 0).exists)
    
    // Test back navigation
    app.navigationBars.buttons.element(boundBy: 0).tap()
    XCTAssertTrue(app.navigationBars["Forums"].exists)
}
```

### Thread Reading Tests

#### Thread Loading and Display
```swift
func testThreadDisplay() {
    navigateToFirstThread()
    
    // Wait for thread to load
    let webView = app.webViews.firstMatch
    XCTAssertTrue(webView.waitForExistence(timeout: 10))
    
    // Verify content exists
    XCTAssertGreaterThan(webView.staticTexts.count, 0)
    
    // Test scrolling
    webView.swipeUp()
    webView.swipeDown()
    
    // Verify navigation elements
    XCTAssertTrue(app.navigationBars.firstMatch.exists)
    XCTAssertTrue(app.toolbars.firstMatch.exists)
}
```

#### Post Interaction
```swift
func testPostInteractions() {
    navigateToFirstThread()
    
    let webView = app.webViews.firstMatch
    XCTAssertTrue(webView.waitForExistence(timeout: 10))
    
    // Test post menu (long press on post)
    let firstPost = webView.children(matching: .other).element(boundBy: 0)
    firstPost.press(forDuration: 1.0)
    
    // Verify action sheet appears
    let actionSheet = app.sheets.firstMatch
    XCTAssertTrue(actionSheet.waitForExistence(timeout: 2))
    
    // Test cancel
    actionSheet.buttons["Cancel"].tap()
    XCTAssertFalse(actionSheet.exists)
}
```

### Authentication Tests

#### Login Flow
```swift
func testLoginFlow() {
    // Navigate to settings
    app.tabBars.buttons["Settings"].tap()
    
    // Tap login cell
    let settingsTable = app.tables.firstMatch
    settingsTable.cells["Login"].tap()
    
    // Verify login screen
    XCTAssertTrue(app.navigationBars["Log In"].exists)
    
    // Enter credentials
    let usernameField = app.textFields["Username"]
    usernameField.tap()
    usernameField.typeText("testuser")
    
    let passwordField = app.secureTextFields["Password"]
    passwordField.tap()
    passwordField.typeText("testpass")
    
    // Submit login
    app.buttons["Log In"].tap()
    
    // Verify success (should navigate back to settings)
    XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
    
    // Verify logged in state
    XCTAssertTrue(settingsTable.cells.containing(.staticText, identifier: "testuser").element.exists)
}
```

#### Logout Flow
```swift
func testLogoutFlow() {
    // Assume already logged in
    loginIfNeeded()
    
    // Navigate to settings
    app.tabBars.buttons["Settings"].tap()
    
    // Tap logout
    let settingsTable = app.tables.firstMatch
    settingsTable.cells["Log Out"].tap()
    
    // Verify confirmation alert
    let alert = app.alerts.firstMatch
    XCTAssertTrue(alert.waitForExistence(timeout: 2))
    
    // Confirm logout
    alert.buttons["Log Out"].tap()
    
    // Verify logged out state
    XCTAssertTrue(settingsTable.cells["Login"].waitForExistence(timeout: 5))
}
```

### Form Testing

#### Reply Composition
```swift
func testReplyComposition() {
    navigateToFirstThread()
    
    // Tap reply button
    app.toolbars.buttons["Reply"].tap()
    
    // Verify compose screen
    XCTAssertTrue(app.navigationBars["Reply"].exists)
    
    // Enter reply text
    let textView = app.textViews.firstMatch
    textView.tap()
    textView.typeText("This is a test reply")
    
    // Test preview
    app.navigationBars.buttons["Preview"].tap()
    XCTAssertTrue(app.webViews.firstMatch.waitForExistence(timeout: 5))
    
    // Go back to editing
    app.navigationBars.buttons["Edit"].tap()
    XCTAssertTrue(textView.exists)
    
    // Cancel reply
    app.navigationBars.buttons["Cancel"].tap()
    
    // Confirm cancellation
    let alert = app.alerts.firstMatch
    if alert.exists {
        alert.buttons["Discard"].tap()
    }
    
    // Verify back to thread
    XCTAssertTrue(app.webViews.firstMatch.exists)
}
```

#### Private Message Composition
```swift
func testPrivateMessageComposition() {
    // Navigate to messages
    app.tabBars.buttons["Messages"].tap()
    
    // Tap compose button
    app.navigationBars.buttons["Compose"].tap()
    
    // Verify compose screen
    XCTAssertTrue(app.navigationBars["New Message"].exists)
    
    // Enter recipient
    let recipientField = app.textFields["To"]
    recipientField.tap()
    recipientField.typeText("testuser")
    
    // Enter subject
    let subjectField = app.textFields["Subject"]
    subjectField.tap()
    subjectField.typeText("Test Subject")
    
    // Enter message
    let messageField = app.textViews.firstMatch
    messageField.tap()
    messageField.typeText("Test message content")
    
    // Test send (but cancel to avoid actually sending)
    app.navigationBars.buttons["Send"].tap()
    
    // If confirmation appears, cancel it
    let alert = app.alerts.firstMatch
    if alert.exists {
        alert.buttons["Cancel"].tap()
    }
}
```

### Settings Tests

#### Theme Switching
```swift
func testThemeSwitching() {
    // Navigate to settings
    app.tabBars.buttons["Settings"].tap()
    
    // Tap theme setting
    let settingsTable = app.tables.firstMatch
    settingsTable.cells["Theme"].tap()
    
    // Verify theme picker
    XCTAssertTrue(app.navigationBars["Theme"].exists)
    
    // Select dark theme
    let themeTable = app.tables.firstMatch
    themeTable.cells["Dark"].tap()
    
    // Go back to settings
    app.navigationBars.buttons["Settings"].tap()
    
    // Verify theme changed (check background color or other visual indicator)
    // Note: Visual verification would need custom accessibility identifiers
    XCTAssertTrue(settingsTable.exists)
}
```

#### Font Size Adjustment
```swift
func testFontSizeAdjustment() {
    // Navigate to settings
    app.tabBars.buttons["Settings"].tap()
    
    // Navigate to posts settings
    let settingsTable = app.tables.firstMatch
    settingsTable.cells["Posts"].tap()
    
    // Find font size slider
    let fontSizeSlider = app.sliders["Font Size"]
    XCTAssertTrue(fontSizeSlider.exists)
    
    // Adjust font size
    fontSizeSlider.adjust(toNormalizedSliderPosition: 0.8)
    
    // Go back and verify setting persisted
    app.navigationBars.buttons["Settings"].tap()
    settingsTable.cells["Posts"].tap()
    
    // Verify slider position maintained
    XCTAssertEqual(fontSizeSlider.normalizedSliderPosition, 0.8, accuracy: 0.1)
}
```

## Advanced UI Testing

### Accessibility Testing

#### VoiceOver Support
```swift
func testVoiceOverSupport() {
    // Enable accessibility testing
    app.launch()
    
    // Navigate to thread list
    navigateToThreadList()
    
    let threadTable = app.tables.firstMatch
    let firstCell = threadTable.cells.element(boundBy: 0)
    
    // Verify accessibility elements exist
    XCTAssertTrue(firstCell.isAccessibilityElement)
    XCTAssertNotNil(firstCell.accessibilityLabel)
    XCTAssertNotNil(firstCell.accessibilityHint)
    
    // Test accessibility actions
    let actions = firstCell.accessibilityCustomActions
    XCTAssertGreaterThan(actions?.count ?? 0, 0)
}
```

#### Dynamic Type Support
```swift
func testDynamicTypeSupport() {
    // Test with different content size categories
    let contentSizes: [UIContentSizeCategory] = [
        .extraSmall,
        .medium,
        .extraExtraLarge,
        .accessibilityExtraExtraExtraLarge
    ]
    
    for contentSize in contentSizes {
        app.terminate()
        app.launchArguments = ["--uitesting", "--content-size", contentSize.rawValue]
        app.launch()
        
        navigateToFirstThread()
        
        // Verify content is readable and accessible
        let webView = app.webViews.firstMatch
        XCTAssertTrue(webView.waitForExistence(timeout: 10))
        
        // Additional verification could include screenshot comparison
        // or checking that text doesn't get truncated
    }
}
```

### Performance Testing

#### Launch Time Testing
```swift
func testLaunchPerformance() {
    measure(metrics: [XCTApplicationLaunchMetric()]) {
        XCUIApplication().launch()
    }
}
```

#### Scroll Performance
```swift
func testScrollPerformance() {
    navigateToFirstThread()
    
    let webView = app.webViews.firstMatch
    XCTAssertTrue(webView.waitForExistence(timeout: 10))
    
    measure(metrics: [XCTOSSignpostMetric.scrollingAndDecelerationMetric]) {
        for _ in 0..<10 {
            webView.swipeUp()
        }
        
        for _ in 0..<10 {
            webView.swipeDown()
        }
    }
}
```

### Error State Testing

#### Network Error Handling
```swift
func testNetworkErrorHandling() {
    // Launch with network errors enabled
    app.launchArguments = ["--uitesting", "--simulate-network-errors"]
    app.launch()
    
    // Try to navigate to thread
    navigateToFirstThread()
    
    // Verify error state
    let errorAlert = app.alerts.firstMatch
    XCTAssertTrue(errorAlert.waitForExistence(timeout: 10))
    
    // Verify retry functionality
    errorAlert.buttons["Retry"].tap()
    
    // Should either succeed or show error again
    // depending on test configuration
}
```

#### Offline State Testing
```swift
func testOfflineState() {
    // Launch in offline mode
    app.launchArguments = ["--uitesting", "--offline-mode"]
    app.launch()
    
    // Navigate to bookmarks (should work offline)
    app.tabBars.buttons["Bookmarks"].tap()
    
    // Verify offline content loads
    let bookmarksTable = app.tables.firstMatch
    XCTAssertTrue(bookmarksTable.waitForExistence(timeout: 5))
    
    // Try to refresh (should show offline message)
    bookmarksTable.swipeDown()
    
    // Verify offline indicator
    XCTAssertTrue(app.staticTexts["Offline"].exists)
}
```

## SwiftUI Testing

### SwiftUI View Testing

#### Basic SwiftUI Navigation
```swift
func testSwiftUINavigation() {
    // Navigate to SwiftUI-based screen
    app.tabBars.buttons["Settings"].tap()
    
    let settingsTable = app.tables.firstMatch
    settingsTable.cells["SwiftUI Settings"].tap()
    
    // Verify SwiftUI screen loaded
    XCTAssertTrue(app.navigationBars["SwiftUI Settings"].exists)
    
    // Test SwiftUI list interaction
    let swiftUIList = app.scrollViews.firstMatch
    XCTAssertTrue(swiftUIList.exists)
    
    // Test SwiftUI button
    app.buttons["Test Button"].tap()
    XCTAssertTrue(app.alerts["SwiftUI Alert"].exists)
}
```

#### SwiftUI Form Testing
```swift
func testSwiftUIForm() {
    navigateToSwiftUISettings()
    
    // Test toggle
    let enableFeatureToggle = app.switches["Enable Feature"]
    XCTAssertTrue(enableFeatureToggle.exists)
    enableFeatureToggle.tap()
    
    // Test picker
    app.buttons["Theme"].tap()
    app.buttons["Dark"].tap()
    
    // Test text field
    let textField = app.textFields["Custom Text"]
    textField.tap()
    textField.typeText("Test Input")
    
    // Test stepper
    let stepper = app.steppers["Count"]
    stepper.buttons["Increment"].tap()
    stepper.buttons["Increment"].tap()
}
```

### UIKit-SwiftUI Interoperability

#### Hybrid Navigation
```swift
func testHybridNavigation() {
    // Start in UIKit
    app.tabBars.buttons["Forums"].tap()
    
    // Navigate to SwiftUI detail view
    let forumsTable = app.tables.firstMatch
    forumsTable.cells.element(boundBy: 0).tap()
    
    // Tap SwiftUI-based action
    app.buttons["SwiftUI Action"].tap()
    
    // Verify SwiftUI sheet presented
    XCTAssertTrue(app.sheets.firstMatch.exists)
    
    // Dismiss and return to UIKit
    app.buttons["Done"].tap()
    XCTAssertTrue(forumsTable.exists)
}
```

## Visual Testing

### Screenshot Testing

#### Baseline Screenshot Capture
```swift
func testScreenshotBaseline() {
    navigateToFirstThread()
    
    let webView = app.webViews.firstMatch
    XCTAssertTrue(webView.waitForExistence(timeout: 10))
    
    // Capture screenshot
    let screenshot = app.screenshot()
    
    // Store baseline (in real implementation, would compare against stored baseline)
    let attachment = XCTAttachment(screenshot: screenshot)
    attachment.name = "thread-view-baseline"
    attachment.lifetime = .keepAlways
    add(attachment)
}
```

#### Theme Comparison Testing
```swift
func testThemeVisualConsistency() {
    let themes = ["Light", "Dark", "OLED"]
    
    for theme in themes {
        // Set theme
        setTheme(theme)
        
        // Navigate to test screen
        navigateToFirstThread()
        
        // Capture screenshot
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "thread-view-\(theme.lowercased())"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
```

### Responsive Design Testing

#### Orientation Testing
```swift
func testOrientationSupport() {
    navigateToFirstThread()
    
    // Test portrait
    XCUIDevice.shared.orientation = .portrait
    let portraitScreenshot = app.screenshot()
    
    // Test landscape
    XCUIDevice.shared.orientation = .landscapeLeft
    let landscapeScreenshot = app.screenshot()
    
    // Verify UI adapts properly
    XCTAssertNotEqual(portraitScreenshot.image.size, landscapeScreenshot.image.size)
    
    // Add screenshots for comparison
    add(XCTAttachment(screenshot: portraitScreenshot, name: "portrait"))
    add(XCTAttachment(screenshot: landscapeScreenshot, name: "landscape"))
}
```

#### Device Size Testing
```swift
func testDeviceSizeAdaptation() {
    // This would typically be run on different simulators
    // Test compact and regular size classes
    
    navigateToFirstThread()
    
    // Verify UI elements are properly sized
    let webView = app.webViews.firstMatch
    XCTAssertTrue(webView.exists)
    
    // Check that content fits properly
    let webViewFrame = webView.frame
    let screenFrame = app.frame
    
    XCTAssertLessThanOrEqual(webViewFrame.width, screenFrame.width)
    XCTAssertLessThanOrEqual(webViewFrame.height, screenFrame.height)
}
```

## Test Utilities and Helpers

### Navigation Helpers

```swift
extension XCUIApplication {
    func navigateToFirstThread() {
        tabBars.buttons["Forums"].tap()
        
        let forumsTable = tables.firstMatch
        forumsTable.cells.element(boundBy: 0).tap()
        
        let threadsTable = tables.firstMatch
        threadsTable.cells.element(boundBy: 0).tap()
    }
    
    func navigateToThreadList() {
        tabBars.buttons["Forums"].tap()
        
        let forumsTable = tables.firstMatch
        forumsTable.cells.element(boundBy: 0).tap()
    }
    
    func loginIfNeeded() {
        tabBars.buttons["Settings"].tap()
        
        let settingsTable = tables.firstMatch
        if settingsTable.cells["Login"].exists {
            performLogin()
        }
    }
    
    private func performLogin() {
        let settingsTable = tables.firstMatch
        settingsTable.cells["Login"].tap()
        
        textFields["Username"].tap()
        textFields["Username"].typeText("testuser")
        
        secureTextFields["Password"].tap()
        secureTextFields["Password"].typeText("testpass")
        
        buttons["Log In"].tap()
    }
}
```

### Waiting and Synchronization

```swift
extension XCTestCase {
    func waitForElementToExist(_ element: XCUIElement, timeout: TimeInterval = 10) {
        let existsPredicate = NSPredicate(format: "exists == true")
        expectation(for: existsPredicate, evaluatedWith: element, handler: nil)
        waitForExpectations(timeout: timeout)
    }
    
    func waitForElementToDisappear(_ element: XCUIElement, timeout: TimeInterval = 10) {
        let notExistsPredicate = NSPredicate(format: "exists == false")
        expectation(for: notExistsPredicate, evaluatedWith: element, handler: nil)
        waitForExpectations(timeout: timeout)
    }
    
    func waitForLoadingToComplete() {
        let loadingIndicator = app.activityIndicators.firstMatch
        if loadingIndicator.exists {
            waitForElementToDisappear(loadingIndicator)
        }
    }
}
```

### Test Data Setup

```swift
extension XCUIApplication {
    func setTheme(_ theme: String) {
        tabBars.buttons["Settings"].tap()
        
        let settingsTable = tables.firstMatch
        settingsTable.cells["Theme"].tap()
        
        let themeTable = tables.firstMatch
        themeTable.cells[theme].tap()
        
        navigationBars.buttons["Settings"].tap()
    }
    
    func clearAllData() {
        launchArguments.append("--clear-all-data")
    }
    
    func useTestData() {
        launchArguments.append("--use-test-data")
    }
}
```

## Test Organization

### Test Suite Structure
```
UITests/
├── Core/
│   ├── NavigationTests.swift
│   ├── AuthenticationTests.swift
│   └── SettingsTests.swift
├── Features/
│   ├── ThreadReadingTests.swift
│   ├── PostCompositionTests.swift
│   └── PrivateMessagesTests.swift
├── Accessibility/
│   ├── VoiceOverTests.swift
│   └── DynamicTypeTests.swift
├── Performance/
│   ├── LaunchPerformanceTests.swift
│   └── ScrollPerformanceTests.swift
├── Visual/
│   ├── ScreenshotTests.swift
│   └── ThemeTests.swift
└── Helpers/
    ├── TestHelpers.swift
    └── XCUIApplication+Extensions.swift
```

### Test Data Management
- Use launch arguments for test configuration
- Create helper methods for common navigation
- Implement page object pattern for complex screens
- Use accessibility identifiers for reliable element selection

## Best Practices

### Reliability
- Use accessibility identifiers instead of text-based selection
- Implement proper waiting strategies
- Handle dynamic content gracefully
- Test on multiple device sizes and orientations

### Maintainability
- Create reusable helper methods
- Use page object pattern for complex screens
- Keep tests focused and atomic
- Document test purposes and setup requirements

### Performance
- Run UI tests on dedicated CI machines
- Use parallel execution when possible
- Optimize test data setup
- Clean up between tests

### Coverage
- Test critical user journeys
- Include error state testing
- Verify accessibility compliance
- Test across different device configurations

## Future Enhancements

### Planned Improvements
- Enhanced visual regression testing
- Automated accessibility auditing
- Cross-platform UI testing (iPad, Mac)
- Integration with design system validation

### Tool Integration
- Fastlane for UI test automation
- Firebase Test Lab for device testing
- Accessibility Inspector integration
- Performance monitoring integration