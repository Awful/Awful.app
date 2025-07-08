# UI Architecture

## Overview

This document describes the user interface architecture of the Awful app, covering both the current UIKit implementation and the planned SwiftUI migration strategy.

## Current UIKit Architecture

### High-Level Structure
```
┌─────────────────────────────────────────────────────────────────┐
│                       UIKit Architecture                        │
│                                                                 │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │ View Controllers│  │  Navigation     │  │  Custom Views   │  │
│  │                 │  │                 │  │                 │  │
│  │ • Table VCs     │  │ • Navigation    │  │ • Table Cells   │  │
│  │ • Collection VCs│  │   Controller    │  │ • Web Views     │  │
│  │ • Page VCs      │  │ • Tab Bar       │  │ • Input Views   │  │
│  │ • Modal VCs     │  │ • Split View    │  │ • Loading Views │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  │
│                                                                 │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │   Storyboards   │  │     Theming     │  │   Auto Layout   │  │
│  │                 │  │                 │  │                 │  │
│  │ • Main Story    │  │ • Theme Manager │  │ • Constraints   │  │
│  │ • Segues        │  │ • Color Schemes │  │ • Size Classes  │  │
│  │ • Prototypes    │  │ • Font Styles   │  │ • Stack Views   │  │
│  │ • Outlets       │  │ • CSS Styling   │  │ • Safe Areas    │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

### View Controller Hierarchy
```
UITabBarController (Root)
├── UINavigationController (Forums)
│   ├── ForumsTableViewController
│   ├── ThreadsTableViewController
│   └── PostsPageViewController
├── UINavigationController (Messages)
│   ├── MessagesTableViewController
│   └── MessageViewController
├── UINavigationController (Settings)
│   └── SettingsTableViewController
└── UINavigationController (More)
    ├── BookmarksTableViewController
    ├── SearchViewController
    └── ProfileViewController
```

### Key View Controllers

#### ForumsTableViewController
```swift
class ForumsTableViewController: UITableViewController {
    // MARK: - Properties
    private var fetchedResultsController: NSFetchedResultsController<Forum>!
    private let forumsClient = ForumsClient.shared
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTableView()
        setupFetchedResultsController()
        setupRefreshControl()
        setupTheming()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshIfNeeded()
    }
    
    // MARK: - Setup
    private func setupTableView() {
        tableView.register(ForumTableViewCell.self, forCellReuseIdentifier: "ForumCell")
        tableView.separatorStyle = .none
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 80
    }
    
    private func setupFetchedResultsController() {
        let request: NSFetchRequest<Forum> = Forum.fetchRequest()
        request.predicate = NSPredicate(format: "isHidden == NO")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Forum.index, ascending: true)]
        
        fetchedResultsController = NSFetchedResultsController(
            fetchRequest: request,
            managedObjectContext: PersistenceController.shared.viewContext,
            sectionNameKeyPath: "category.name",
            cacheName: nil
        )
        
        fetchedResultsController.delegate = self
        
        do {
            try fetchedResultsController.performFetch()
        } catch {
            print("Fetch failed: \(error)")
        }
    }
    
    // MARK: - Table View Data Source
    override func numberOfSections(in tableView: UITableView) -> Int {
        return fetchedResultsController.sections?.count ?? 0
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return fetchedResultsController.sections?[section].numberOfObjects ?? 0
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ForumCell", for: indexPath) as! ForumTableViewCell
        let forum = fetchedResultsController.object(at: indexPath)
        cell.configure(with: forum)
        return cell
    }
    
    // MARK: - Table View Delegate
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let forum = fetchedResultsController.object(at: indexPath)
        showThreads(for: forum)
    }
    
    // MARK: - Navigation
    private func showThreads(for forum: Forum) {
        let threadsVC = ThreadsTableViewController()
        threadsVC.forum = forum
        navigationController?.pushViewController(threadsVC, animated: true)
    }
}
```

#### PostsPageViewController
```swift
class PostsPageViewController: UIViewController {
    // MARK: - Properties
    @IBOutlet weak var webView: WKWebView!
    @IBOutlet weak var loadingIndicator: UIActivityIndicatorView!
    
    var thread: Thread?
    private var currentPage = 1
    private var posts: [Post] = []
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupWebView()
        setupNavigationBar()
        loadPosts()
    }
    
    // MARK: - Setup
    private func setupWebView() {
        webView.navigationDelegate = self
        webView.scrollView.delegate = self
        webView.configuration.userContentController.add(self, name: "postAction")
    }
    
    private func setupNavigationBar() {
        title = thread?.title
        
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(title: "Reply", style: .plain, target: self, action: #selector(composeReply)),
            UIBarButtonItem(title: "Action", style: .plain, target: self, action: #selector(showActionSheet))
        ]
    }
    
    // MARK: - Loading
    private func loadPosts() {
        guard let thread = thread else { return }
        
        loadingIndicator.startAnimating()
        
        Task {
            do {
                let newPosts = try await ForumsClient.shared.loadPosts(for: thread, page: currentPage)
                await MainActor.run {
                    self.posts.append(contentsOf: newPosts)
                    self.renderHTML()
                    self.loadingIndicator.stopAnimating()
                }
            } catch {
                await MainActor.run {
                    self.showError(error)
                    self.loadingIndicator.stopAnimating()
                }
            }
        }
    }
    
    private func renderHTML() {
        let template = PostsTemplate()
        let html = template.render(posts: posts, theme: Theme.current)
        webView.loadHTMLString(html, baseURL: nil)
    }
}
```

### Custom Views

#### ForumTableViewCell
```swift
class ForumTableViewCell: UITableViewCell {
    // MARK: - UI Elements
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let unreadIndicator = UIView()
    private let iconImageView = UIImageView()
    
    // MARK: - Initialization
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
        setupConstraints()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    private func setupViews() {
        contentView.addSubview(iconImageView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(subtitleLabel)
        contentView.addSubview(unreadIndicator)
        
        titleLabel.font = .systemFont(ofSize: 16, weight: .medium)
        subtitleLabel.font = .systemFont(ofSize: 14, weight: .regular)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.numberOfLines = 2
        
        unreadIndicator.backgroundColor = .systemBlue
        unreadIndicator.layer.cornerRadius = 4
        unreadIndicator.isHidden = true
        
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = .systemBlue
    }
    
    private func setupConstraints() {
        [iconImageView, titleLabel, subtitleLabel, unreadIndicator].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        
        NSLayoutConstraint.activate([
            iconImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            iconImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 32),
            iconImageView.heightAnchor.constraint(equalToConstant: 32),
            
            titleLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 12),
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: unreadIndicator.leadingAnchor, constant: -8),
            
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            subtitleLabel.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -12),
            
            unreadIndicator.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            unreadIndicator.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            unreadIndicator.widthAnchor.constraint(equalToConstant: 8),
            unreadIndicator.heightAnchor.constraint(equalToConstant: 8)
        ])
    }
    
    // MARK: - Configuration
    func configure(with forum: Forum) {
        titleLabel.text = forum.title
        subtitleLabel.text = forum.subtitle
        unreadIndicator.isHidden = !forum.hasUnreadThreads
        
        // Set forum icon
        iconImageView.image = UIImage(systemName: forum.iconName ?? "folder")
    }
}
```

## SwiftUI Migration Architecture

### Target SwiftUI Structure
```
┌─────────────────────────────────────────────────────────────────┐
│                      SwiftUI Architecture                       │
│                                                                 │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │     Views       │  │   View Models   │  │   Navigation    │  │
│  │                 │  │                 │  │                 │  │
│  │ • ForumsListView│  │ • ForumsViewModel│  │ • NavigationView│  │
│  │ • ThreadsListView│ │ • ThreadsViewModel│ │ • TabView       │  │
│  │ • PostsView     │  │ • PostsViewModel │  │ • Sheets        │  │
│  │ • SettingsView  │  │ • SettingsViewModel│ │ • Navigation    │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  │
│                                                                 │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │ State Management│  │   Environment   │  │   Modifiers     │  │
│  │                 │  │                 │  │                 │  │
│  │ • @State        │  │ • @Environment  │  │ • Themed        │  │
│  │ • @StateObject  │  │ • @EnvironmentObject│ • Animated    │  │
│  │ • @ObservedObject│ │ • Theme Manager │  │ • Accessibility │  │
│  │ • @FetchRequest │  │ • Settings      │  │ • Layout        │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

### SwiftUI View Hierarchy
```swift
struct ContentView: View {
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var authManager = AuthenticationManager.shared
    
    var body: some View {
        Group {
            if authManager.isAuthenticated {
                MainTabView()
            } else {
                LoginView()
            }
        }
        .environmentObject(themeManager)
        .environmentObject(authManager)
        .onAppear {
            themeManager.loadCurrentTheme()
            authManager.checkAuthenticationStatus()
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            NavigationView {
                ForumsListView()
            }
            .tabItem {
                Image(systemName: "list.bullet")
                Text("Forums")
            }
            
            NavigationView {
                MessagesListView()
            }
            .tabItem {
                Image(systemName: "envelope")
                Text("Messages")
            }
            
            NavigationView {
                BookmarksListView()
            }
            .tabItem {
                Image(systemName: "bookmark")
                Text("Bookmarks")
            }
            
            NavigationView {
                SettingsView()
            }
            .tabItem {
                Image(systemName: "gear")
                Text("Settings")
            }
        }
    }
}
```

### SwiftUI Views

#### ForumsListView
```swift
struct ForumsListView: View {
    @StateObject private var viewModel = ForumsViewModel()
    @EnvironmentObject var theme: ThemeManager
    
    var body: some View {
        List {
            ForEach(viewModel.forumSections, id: \.name) { section in
                Section(section.name) {
                    ForEach(section.forums) { forum in
                        NavigationLink(destination: ThreadsListView(forum: forum)) {
                            ForumRowView(forum: forum)
                        }
                    }
                }
            }
        }
        .navigationTitle("Forums")
        .refreshable {
            await viewModel.refresh()
        }
        .searchable(text: $viewModel.searchText)
        .onAppear {
            Task {
                await viewModel.loadForumsIfNeeded()
            }
        }
        .alert("Error", isPresented: .constant(viewModel.error != nil)) {
            Button("OK") {
                viewModel.error = nil
            }
        } message: {
            if let error = viewModel.error {
                Text(error.localizedDescription)
            }
        }
    }
}

struct ForumRowView: View {
    let forum: Forum
    @EnvironmentObject var theme: ThemeManager
    
    var body: some View {
        HStack {
            AsyncImage(url: forum.iconURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                Image(systemName: "folder")
                    .foregroundColor(theme.accentColor)
            }
            .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(forum.title)
                    .font(.headline)
                    .foregroundColor(theme.primaryTextColor)
                
                if let subtitle = forum.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(theme.secondaryTextColor)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            if forum.hasUnreadThreads {
                Circle()
                    .fill(theme.accentColor)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, 4)
    }
}
```

#### ThreadsListView
```swift
struct ThreadsListView: View {
    let forum: Forum
    @StateObject private var viewModel: ThreadsViewModel
    @EnvironmentObject var theme: ThemeManager
    
    init(forum: Forum) {
        self.forum = forum
        self._viewModel = StateObject(wrappedValue: ThreadsViewModel(forum: forum))
    }
    
    var body: some View {
        List {
            ForEach(viewModel.threads) { thread in
                NavigationLink(destination: PostsView(thread: thread)) {
                    ThreadRowView(thread: thread)
                }
                .swipeActions(edge: .trailing) {
                    Button("Mark Read") {
                        viewModel.markAsRead(thread)
                    }
                    .tint(.blue)
                    
                    Button("Bookmark") {
                        viewModel.toggleBookmark(thread)
                    }
                    .tint(.orange)
                }
            }
        }
        .navigationTitle(forum.title)
        .navigationBarTitleDisplayMode(.large)
        .refreshable {
            await viewModel.refresh()
        }
        .searchable(text: $viewModel.searchText)
        .onAppear {
            Task {
                await viewModel.loadThreadsIfNeeded()
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Compose") {
                    viewModel.showCompose = true
                }
            }
        }
        .sheet(isPresented: $viewModel.showCompose) {
            ComposeThreadView(forum: forum)
        }
    }
}

struct ThreadRowView: View {
    let thread: Thread
    @EnvironmentObject var theme: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if thread.isSticky {
                    Image(systemName: "pin.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                }
                
                Text(thread.title)
                    .font(.headline)
                    .foregroundColor(thread.hasUnreadPosts ? theme.accentColor : theme.primaryTextColor)
                    .lineLimit(2)
                
                Spacer()
                
                if thread.hasUnreadPosts {
                    Text("\(thread.unreadPostCount)")
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(theme.accentColor)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
            }
            
            HStack {
                Text("by \(thread.author ?? "Unknown")")
                    .font(.caption)
                    .foregroundColor(theme.secondaryTextColor)
                
                Spacer()
                
                if let lastPostDate = thread.lastPostDate {
                    Text(lastPostDate, style: .relative)
                        .font(.caption)
                        .foregroundColor(theme.secondaryTextColor)
                }
                
                Text("• \(thread.postCount) posts")
                    .font(.caption)
                    .foregroundColor(theme.secondaryTextColor)
            }
        }
        .padding(.vertical, 4)
    }
}
```

### View Models

#### ForumsViewModel
```swift
@MainActor
class ForumsViewModel: ObservableObject {
    @Published var forumSections: [ForumSection] = []
    @Published var searchText = ""
    @Published var isLoading = false
    @Published var error: Error?
    
    private let forumsService: ForumsService
    private var cancellables = Set<AnyCancellable>()
    
    init(forumsService: ForumsService = ForumsService()) {
        self.forumsService = forumsService
        setupSearchFiltering()
    }
    
    func loadForumsIfNeeded() async {
        guard forumSections.isEmpty && !isLoading else { return }
        await loadForums()
    }
    
    func refresh() async {
        await loadForums()
    }
    
    private func loadForums() async {
        isLoading = true
        error = nil
        
        do {
            let sections = try await forumsService.loadForumSections()
            forumSections = sections
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
    
    private func setupSearchFiltering() {
        $searchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] searchText in
                self?.filterForums(searchText: searchText)
            }
            .store(in: &cancellables)
    }
    
    private func filterForums(searchText: String) {
        // Implement forum filtering logic
    }
}

struct ForumSection {
    let name: String
    let forums: [Forum]
}
```

### State Management Patterns

#### Environment Objects
```swift
// Theme management
class ThemeManager: ObservableObject {
    @Published var currentTheme: Theme = .light
    
    static let shared = ThemeManager()
    
    func applyTheme(_ theme: Theme) {
        currentTheme = theme
        UserDefaults.standard.set(theme.rawValue, forKey: "selectedTheme")
    }
    
    var primaryTextColor: Color {
        currentTheme.primaryTextColor
    }
    
    var backgroundColor: Color {
        currentTheme.backgroundColor
    }
    
    var accentColor: Color {
        currentTheme.accentColor
    }
}

// Usage in views
struct SomeView: View {
    @EnvironmentObject var theme: ThemeManager
    
    var body: some View {
        Text("Hello")
            .foregroundColor(theme.primaryTextColor)
            .background(theme.backgroundColor)
    }
}
```

#### Core Data Integration
```swift
struct ThreadsListView: View {
    let forum: Forum
    
    @FetchRequest private var threads: FetchedResults<Thread>
    
    init(forum: Forum) {
        self.forum = forum
        self._threads = FetchRequest(
            entity: Thread.entity(),
            sortDescriptors: [
                NSSortDescriptor(keyPath: \Thread.isSticky, ascending: false),
                NSSortDescriptor(keyPath: \Thread.lastPostDate, ascending: false)
            ],
            predicate: NSPredicate(format: "forum == %@", forum),
            animation: .default
        )
    }
    
    var body: some View {
        List(threads) { thread in
            ThreadRowView(thread: thread)
        }
    }
}
```

## Navigation Patterns

### UIKit Navigation
```swift
// Storyboard-based navigation
override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    if segue.identifier == "ShowThreads",
       let destination = segue.destination as? ThreadsTableViewController,
       let forum = sender as? Forum {
        destination.forum = forum
    }
}

// Programmatic navigation
private func showThread(_ thread: Thread) {
    let postsVC = PostsPageViewController()
    postsVC.thread = thread
    navigationController?.pushViewController(postsVC, animated: true)
}
```

### SwiftUI Navigation
```swift
// NavigationLink-based navigation
NavigationLink(destination: ThreadsListView(forum: forum)) {
    ForumRowView(forum: forum)
}

// Programmatic navigation
struct ContentView: View {
    @State private var selectedThread: Thread?
    
    var body: some View {
        NavigationView {
            ThreadsList()
                .navigationDestination(item: $selectedThread) { thread in
                    PostsView(thread: thread)
                }
        }
    }
}
```

## Testing Strategy

### UIKit Testing
```swift
class ForumsTableViewControllerTests: XCTestCase {
    var viewController: ForumsTableViewController!
    var mockContext: NSManagedObjectContext!
    
    override func setUp() {
        super.setUp()
        
        // Setup test Core Data stack
        mockContext = setupTestCoreDataStack()
        
        viewController = ForumsTableViewController()
        viewController.loadViewIfNeeded()
    }
    
    func testTableViewSetup() {
        XCTAssertNotNil(viewController.tableView)
        XCTAssertEqual(viewController.tableView.numberOfSections, 0)
    }
    
    func testCellConfiguration() {
        // Create test forum
        let forum = Forum(context: mockContext)
        forum.title = "Test Forum"
        
        let cell = ForumTableViewCell()
        cell.configure(with: forum)
        
        XCTAssertEqual(cell.titleLabel.text, "Test Forum")
    }
}
```

### SwiftUI Testing
```swift
class ForumsListViewTests: XCTestCase {
    func testForumsListView() {
        let view = ForumsListView()
        let hostingController = UIHostingController(rootView: view)
        
        XCTAssertNotNil(hostingController.view)
    }
    
    func testForumRowView() {
        let forum = createTestForum()
        let view = ForumRowView(forum: forum)
        
        let hostingController = UIHostingController(rootView: view)
        XCTAssertNotNil(hostingController.view)
    }
}
```

## Best Practices

### UIKit Best Practices
1. Use MVC pattern consistently
2. Implement proper memory management
3. Handle view lifecycle correctly
4. Use Auto Layout for responsive design
5. Implement accessibility features

### SwiftUI Best Practices
1. Use MVVM pattern for complex views
2. Minimize state complexity
3. Use @StateObject for owned objects
4. Use @ObservedObject for passed objects
5. Implement proper data flow
6. Use environment objects for shared state
7. Create reusable view modifiers
8. Test view logic separately from UI