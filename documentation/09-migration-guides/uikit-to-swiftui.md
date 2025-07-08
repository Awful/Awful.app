# UIKit to SwiftUI Migration Guide

## Overview

This guide covers the migration strategy for converting Awful's UIKit-based interface to SwiftUI, including best practices, common patterns, and implementation details.

## Migration Strategy

### Phase 1: Foundation Components
- Establish SwiftUI theme system
- Create base SwiftUI components
- Implement navigation patterns
- Set up data binding architecture

### Phase 2: Core Views
- Forum list view
- Thread list view
- Post view (web-based)
- Settings screens

### Phase 3: Complex Features
- Post composition
- Private messaging
- Search functionality
- User profiles

### Phase 4: Advanced Features
- Smilie keyboard integration
- Custom gestures
- Performance optimization
- Accessibility improvements

## Architecture Changes

### Data Flow
```
UIKit: ViewController → NSFetchedResultsController → Core Data
SwiftUI: View → @ObservedObject/@StateObject → ObservableObject → Core Data
```

### Navigation
```
UIKit: UINavigationController + Storyboard segues
SwiftUI: NavigationView/NavigationStack + programmatic navigation
```

### State Management
```
UIKit: View controller properties + delegation
SwiftUI: @State, @Binding, @ObservedObject, @EnvironmentObject
```

## Component Migration Patterns

### Table Views → Lists
```swift
// UIKit
class ThreadsTableViewController: UITableViewController {
    var fetchedResultsController: NSFetchedResultsController<Thread>!
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ThreadCell", for: indexPath)
        let thread = fetchedResultsController.object(at: indexPath)
        // Configure cell...
        return cell
    }
}

// SwiftUI
struct ThreadsListView: View {
    @FetchRequest(entity: Thread.entity(), sortDescriptors: [])
    private var threads: FetchedResults<Thread>
    
    var body: some View {
        List(threads) { thread in
            ThreadRowView(thread: thread)
        }
    }
}
```

### View Controllers → Views
```swift
// UIKit
class PostsPageViewController: UIViewController {
    @IBOutlet weak var webView: WKWebView!
    var thread: Thread?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        loadPosts()
    }
}

// SwiftUI
struct PostsPageView: View {
    let thread: Thread
    @StateObject private var viewModel = PostsViewModel()
    
    var body: some View {
        WebView(htmlString: viewModel.htmlString)
            .onAppear {
                viewModel.loadPosts(for: thread)
            }
    }
}
```

### Theming Integration
```swift
// UIKit
override func viewDidLoad() {
    super.viewDidLoad()
    Theme.currentTheme.apply(to: view)
}

// SwiftUI
struct ContentView: View {
    @EnvironmentObject var theme: ThemeManager
    
    var body: some View {
        VStack {
            // Content
        }
        .foregroundColor(theme.textColor)
        .background(theme.backgroundColor)
    }
}
```

## Data Binding Migration

### Core Data Integration
```swift
// UIKit - NSFetchedResultsController
class ForumsTableViewController: UITableViewController, NSFetchedResultsControllerDelegate {
    lazy var fetchedResultsController: NSFetchedResultsController<Forum> = {
        let request: NSFetchRequest<Forum> = Forum.fetchRequest()
        let controller = NSFetchedResultsController(fetchRequest: request, 
                                                   managedObjectContext: context, 
                                                   sectionNameKeyPath: nil, 
                                                   cacheName: nil)
        controller.delegate = self
        return controller
    }()
}

// SwiftUI - @FetchRequest
struct ForumsListView: View {
    @FetchRequest(
        entity: Forum.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Forum.index, ascending: true)]
    ) var forums: FetchedResults<Forum>
    
    var body: some View {
        List(forums) { forum in
            ForumRowView(forum: forum)
        }
    }
}
```

### ObservableObject Pattern
```swift
class ForumsViewModel: ObservableObject {
    @Published var forums: [Forum] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private let forumsClient = ForumsClient.shared
    
    func loadForums() {
        isLoading = true
        forumsClient.loadForums { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success(let forums):
                    self?.forums = forums
                case .failure(let error):
                    self?.error = error
                }
            }
        }
    }
}
```

## Navigation Migration

### UIKit Navigation
```swift
// Storyboard-based navigation
performSegue(withIdentifier: "ShowThread", sender: thread)

// Programmatic navigation
let postsVC = PostsPageViewController()
postsVC.thread = thread
navigationController?.pushViewController(postsVC, animated: true)
```

### SwiftUI Navigation
```swift
// NavigationLink-based navigation
NavigationLink(destination: PostsPageView(thread: thread)) {
    ThreadRowView(thread: thread)
}

// Programmatic navigation
struct ThreadsListView: View {
    @State private var selectedThread: Thread?
    
    var body: some View {
        NavigationView {
            List(threads) { thread in
                ThreadRowView(thread: thread)
                    .onTapGesture {
                        selectedThread = thread
                    }
            }
            .navigationDestination(item: $selectedThread) { thread in
                PostsPageView(thread: thread)
            }
        }
    }
}
```

## Testing Migration

### UIKit Testing
```swift
class ThreadsTableViewControllerTests: XCTestCase {
    var viewController: ThreadsTableViewController!
    
    override func setUp() {
        super.setUp()
        viewController = ThreadsTableViewController()
        viewController.loadViewIfNeeded()
    }
    
    func testTableViewLoads() {
        XCTAssertNotNil(viewController.tableView)
    }
}
```

### SwiftUI Testing
```swift
class ThreadsListViewTests: XCTestCase {
    func testThreadsListView() {
        let view = ThreadsListView()
        let hostingController = UIHostingController(rootView: view)
        
        // Test view hierarchy
        XCTAssertNotNil(hostingController.view)
    }
}
```

## Performance Considerations

### LazyVStack for Large Lists
```swift
// Instead of List for very large datasets
ScrollView {
    LazyVStack {
        ForEach(posts) { post in
            PostRowView(post: post)
        }
    }
}
```

### ViewBuilder Optimization
```swift
// Extract complex views to separate structs
struct ThreadRowView: View {
    let thread: Thread
    
    var body: some View {
        HStack {
            ThreadIconView(thread: thread)
            ThreadContentView(thread: thread)
            Spacer()
            ThreadMetadataView(thread: thread)
        }
    }
}
```

## Common Pitfalls

### 1. Direct UIKit → SwiftUI Translation
- Don't directly translate UIKit patterns
- Embrace SwiftUI's declarative nature
- Use appropriate state management

### 2. Over-complicated State Management
- Keep state close to where it's used
- Use `@State` for local state
- Use `@ObservedObject` for shared state

### 3. Performance Issues
- Avoid unnecessary view updates
- Use `@StateObject` vs `@ObservedObject` correctly
- Profile and optimize rendering

## Migration Checklist

- [ ] Set up SwiftUI theme system
- [ ] Create base SwiftUI components
- [ ] Implement navigation patterns
- [ ] Migrate core data integration
- [ ] Convert table views to lists
- [ ] Update state management
- [ ] Implement proper data binding
- [ ] Add SwiftUI testing
- [ ] Performance optimization
- [ ] Accessibility updates

## Resources

- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)
- [Core Data with SwiftUI](https://developer.apple.com/documentation/coredata/using_core_data_with_swiftui)
- [SwiftUI Navigation](https://developer.apple.com/documentation/swiftui/navigation)
- [Testing SwiftUI Views](https://developer.apple.com/documentation/swiftui/testing-swiftui-views)