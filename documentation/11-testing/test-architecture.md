# Test Architecture

## Overview

The Awful.app testing architecture is built on XCTest and follows a multi-layered approach that mirrors the application's modular structure. This document outlines the testing framework, organization, and architectural patterns used throughout the project.

## Test Target Structure

### Core Test Targets

#### AwfulTests
- **Purpose**: Tests main iOS app functionality
- **Location**: `App/Tests/`
- **Scope**: View controllers, app-level logic, UI components
- **Configuration**: Main queue concurrency, iOS simulator required

#### AwfulCoreTests
- **Purpose**: Tests networking, data persistence, and forum scraping
- **Location**: `AwfulCore/Tests/AwfulCoreTests/`
- **Scope**: Core Data operations, HTML parsing, HTTP client
- **Configuration**: Parallelizable, in-memory store

#### AwfulExtensionsTests
- **Purpose**: Tests utility functions and extensions
- **Location**: `AwfulExtensions/Tests/`
- **Scope**: Swift extensions, UIKit helpers
- **Configuration**: Parallelizable, lightweight

#### SmiliesTests
- **Purpose**: Tests smilie keyboard functionality
- **Location**: `Smilies/Tests/SmiliesTests/`
- **Scope**: Smilie parsing, keyboard extension, data management
- **Configuration**: Parallelizable, Objective-C compatible

#### AwfulScrapingTests
- **Purpose**: Tests HTML scraping and parsing utilities
- **Location**: `AwfulScraping/Tests/AwfulScrapingTests/`
- **Scope**: HTML parsing, data extraction, decoding strategies
- **Configuration**: Parallelizable, fixture-based

## Test Organization Principles

### Layered Testing Strategy

```
┌─────────────────────────────────────────────┐
│                UI Tests                     │
│         (End-to-End Scenarios)             │
├─────────────────────────────────────────────┤
│             Integration Tests               │
│      (Multi-component Interactions)        │
├─────────────────────────────────────────────┤
│               Unit Tests                    │
│         (Individual Components)            │
├─────────────────────────────────────────────┤
│              Test Fixtures                  │
│       (Mock Data and Test Helpers)         │
└─────────────────────────────────────────────┘
```

### Test Categories

#### Functional Tests
- **Authentication**: Login/logout flows, session management
- **Data Operations**: CRUD operations, Core Data stack
- **Scraping**: HTML parsing, form handling
- **Networking**: HTTP requests, response handling

#### Non-Functional Tests
- **Performance**: Memory usage, response times
- **Reliability**: Error handling, crash recovery
- **Compatibility**: iOS version support, device variations

#### Migration Tests
- **Regression**: Ensuring existing functionality works
- **Parity**: SwiftUI vs UIKit behavior matching
- **Data Migration**: Core Data schema changes

## Test Infrastructure

### Test Plan Configuration

```json
{
  "testTargets": [
    {
      "name": "AwfulCoreTests",
      "parallelizable": true,
      "containerPath": "container:AwfulCore"
    },
    {
      "name": "AwfulTests",
      "parallelizable": true,
      "containerPath": "container:Awful.xcodeproj"
    }
  ],
  "defaultOptions": {
    "codeCoverage": false,
    "commandLineArgumentEntries": [
      {
        "argument": "-com.apple.CoreData.SQLDebug 1",
        "enabled": false
      }
    ]
  }
}
```

### Test Initialization

```swift
// Global test setup for consistent environment
let testInit: () -> Void = {
    // Set known timezone for reliable date parsing
    NSTimeZone.default = TimeZone(identifier: "America/Chicago")!
    return {}
}()

// Usage in test classes
override class func setUp() {
    super.setUp()
    testInit()
}
```

### Test Helpers and Fixtures

#### HTML Fixture Loading
```swift
func htmlFixture(named basename: String) throws -> HTMLDocument {
    let fixtureURL = Bundle.module.url(forResource: basename, 
                                      withExtension: "html", 
                                      subdirectory: "Fixtures")!
    let string = try String(contentsOf: fixtureURL, encoding: .windowsCP1252)
    return HTMLDocument(string: string)
}
```

#### In-Memory Core Data Stack
```swift
func makeInMemoryStoreContext() -> NSManagedObjectContext {
    let psc = NSPersistentStoreCoordinator(managedObjectModel: DataStore.model)
    try! psc.addPersistentStore(ofType: NSInMemoryStoreType, 
                               configurationName: nil, at: nil)
    let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
    context.persistentStoreCoordinator = psc
    return context
}
```

## Testing Patterns

### Scraping Tests Pattern
```swift
final class PostScrapingTests: XCTestCase {
    func testIgnoredPost() throws {
        let result = try scrapeHTMLFixture(ShowPostScrapeResult.self, named: "showpost")
        XCTAssertEqual(result.author.username, "The Dave")
        XCTAssert(result.post.body.contains("Which command?"))
        XCTAssertEqual(result.threadID?.rawValue, "3510131")
    }
}
```

### Persistence Tests Pattern
```swift
final class ThreadListPersistenceTests: XCTestCase {
    var context: NSManagedObjectContext!
    
    override func setUp() {
        super.setUp()
        context = makeInMemoryStoreContext()
    }
    
    func testThreadPersistence() throws {
        // Test Core Data operations
    }
}
```

### Form Tests Pattern
```swift
final class IgnoreListFormTests: XCTestCase {
    func testFormScraping() throws {
        let form = try scrapeForm(matchingSelector: "form[name='ignorelist']", 
                                 inFixtureNamed: "ignorelist")
        XCTAssertEqual(form.textboxes.count, 2)
    }
}
```

## Test Data Management

### Fixture Organization
```
Tests/
├── Fixtures/
│   ├── HTML/
│   │   ├── showpost.html
│   │   ├── threadlist.html
│   │   └── profile.html
│   └── JSON/
│       ├── announcements.json
│       └── privatemessages.json
└── TestHelpers/
    ├── Helpers.swift
    └── MockObjects.swift
```

### Test Double Strategy
- **Stubs**: For predictable responses
- **Mocks**: For behavior verification
- **Fakes**: For simplified implementations
- **Spies**: For interaction tracking

## Architecture Benefits

### Modularity
- Each test target focuses on its specific domain
- Clear separation of concerns
- Easy to run specific test suites

### Maintainability
- Consistent patterns across test targets
- Shared test utilities and fixtures
- Clear naming conventions

### Reliability
- Isolated test environments
- Deterministic test data
- Consistent setup/teardown

### Performance
- Parallelizable test execution
- In-memory data stores
- Efficient fixture loading

## Testing Philosophy

### Test Pyramid Principles
1. **Many Unit Tests**: Fast, isolated, focused
2. **Some Integration Tests**: Multi-component interactions
3. **Few UI Tests**: End-to-end user scenarios

### Quality Gates
- All tests must pass before merge
- Code coverage monitoring (when enabled)
- Performance regression detection
- Memory leak detection

## Migration Considerations

### Testing Strategy for SwiftUI Migration
1. **Parallel Testing**: Run both UIKit and SwiftUI implementations
2. **Behavior Preservation**: Ensure identical functionality
3. **Performance Comparison**: Benchmark before/after
4. **Visual Regression**: Screenshot comparison testing

### Test Architecture Evolution
- Gradual migration of test patterns
- Maintaining backward compatibility
- Introducing SwiftUI-specific test helpers
- Preserving existing test coverage

## Best Practices

### Test Organization
- One test class per production class
- Descriptive test method names
- Logical grouping of related tests
- Clear arrange/act/assert structure

### Test Data
- Use realistic but anonymized data
- Maintain fixture freshness
- Version control test data
- Document fixture purposes

### Test Execution
- Run tests locally before committing
- Use CI/CD for automated testing
- Monitor test execution times
- Address flaky tests immediately

## Future Enhancements

### Planned Improvements
- Enhanced code coverage reporting
- Visual regression testing
- Performance benchmarking suite
- SwiftUI-specific test utilities
- Accessibility testing framework

### Tool Integration
- Fastlane for test automation
- Danger for PR validation
- SwiftLint for test code quality
- Instruments for performance testing