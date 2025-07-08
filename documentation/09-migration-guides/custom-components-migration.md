# Custom Components Migration Guide

## Overview

This guide covers migrating Awful.app's specialized UI components from UIKit to SwiftUI, including complex web views, custom controls, and unique interface elements.

## Current Custom Components

### UIKit Implementation
```swift
// Current custom post view controller
class PostsPageViewController: UIViewController {
    @IBOutlet weak var webView: WKWebView!
    @IBOutlet weak var toolbar: UIToolbar!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    var thread: Thread?
    var currentPage: Int = 1
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupWebView()
        setupToolbar()
        loadPosts()
    }
    
    private func setupWebView() {
        webView.navigationDelegate = self
        webView.uiDelegate = self
        
        // Custom JavaScript injection
        let script = WKUserScript(
            source: customJavaScript,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        webView.configuration.userContentController.addUserScript(script)
    }
    
    private func setupToolbar() {
        // Custom toolbar items
        let previousButton = UIBarButtonItem(
            image: UIImage(systemName: "chevron.left"),
            style: .plain,
            target: self,
            action: #selector(previousPage)
        )
        
        let nextButton = UIBarButtonItem(
            image: UIImage(systemName: "chevron.right"),
            style: .plain,
            target: self,
            action: #selector(nextPage)
        )
        
        toolbar.setItems([previousButton, nextButton], animated: false)
    }
}

// Custom smilie keyboard
class SmilieKeyboard: UIInputViewController {
    var collectionView: UICollectionView!
    var smilies: [Smilie] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCollectionView()
        loadSmilies()
    }
    
    private func setupCollectionView() {
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: 44, height: 44)
        layout.minimumInteritemSpacing = 8
        layout.minimumLineSpacing = 8
        
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.register(SmilieCell.self, forCellWithReuseIdentifier: "SmilieCell")
        
        view.addSubview(collectionView)
    }
}
```

### Key Custom Components
1. **PostsPageViewController**: Web view with custom JavaScript
2. **SmilieKeyboard**: Custom keyboard extension
3. **ComposeViewController**: Rich text editing
4. **ProfileView**: User profile display
5. **SettingsViewController**: Complex settings interface
6. **Custom Cells**: Specialized table/collection view cells

## SwiftUI Migration Strategy

### Phase 1: Web View Component

Convert web view to SwiftUI:

```swift
// New PostsWebView.swift
struct PostsWebView: UIViewRepresentable {
    let thread: Thread
    @Binding var currentPage: Int
    @Binding var isLoading: Bool
    
    @Environment(\.theme) var theme
    @EnvironmentObject var webViewManager: WebViewManager
    
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        setupConfiguration(configuration, context: context)
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        if context.coordinator.currentThread != thread {
            context.coordinator.currentThread = thread
            loadPosts(in: webView)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func setupConfiguration(_ config: WKWebViewConfiguration, context: Context) {
        // JavaScript injection
        let script = WKUserScript(
            source: customJavaScript,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        config.userContentController.addUserScript(script)
        
        // Message handlers
        config.userContentController.add(context.coordinator, name: "postTapped")
        config.userContentController.add(context.coordinator, name: "linkClicked")
    }
    
    private func loadPosts(in webView: WKWebView) {
        Task {
            isLoading = true
            
            do {
                let html = try await webViewManager.generateHTML(
                    for: thread,
                    page: currentPage,
                    theme: theme
                )
                
                await MainActor.run {
                    webView.loadHTMLString(html, baseURL: nil)
                }
            } catch {
                print("Failed to load posts: \(error)")
            }
            
            isLoading = false
        }
    }
    
    // Custom JavaScript for post interaction
    private var customJavaScript: String {
        """
        // Handle post tapping
        document.addEventListener('click', function(event) {
            if (event.target.closest('.post')) {
                var postId = event.target.closest('.post').dataset.postId;
                window.webkit.messageHandlers.postTapped.postMessage(postId);
            }
        });
        
        // Handle link clicking
        document.addEventListener('click', function(event) {
            if (event.target.tagName === 'A') {
                event.preventDefault();
                var href = event.target.href;
                window.webkit.messageHandlers.linkClicked.postMessage(href);
            }
        });
        
        // Custom styling
        document.addEventListener('DOMContentLoaded', function() {
            document.body.style.backgroundColor = '\(theme.colors.background.hex)';
            document.body.style.color = '\(theme.colors.primaryText.hex)';
        });
        """
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        var parent: PostsWebView
        var currentThread: Thread?
        
        init(_ parent: PostsWebView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.isLoading = true
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            switch message.name {
            case "postTapped":
                if let postId = message.body as? String {
                    handlePostTap(postId: postId)
                }
            case "linkClicked":
                if let href = message.body as? String {
                    handleLinkClick(href: href)
                }
            default:
                break
            }
        }
        
        private func handlePostTap(postId: String) {
            // Handle post selection
            parent.webViewManager.selectPost(id: postId)
        }
        
        private func handleLinkClick(href: String) {
            // Handle link navigation
            parent.webViewManager.openLink(href)
        }
    }
}

// Web view manager for data and actions
@MainActor
class WebViewManager: ObservableObject {
    @Published var selectedPostId: String?
    @Published var showingLinkSheet = false
    @Published var currentLink: String?
    
    private let forumsClient = ForumsClient.shared
    private let themeManager = SwiftUIThemeManager.shared
    
    func generateHTML(for thread: Thread, page: Int, theme: AwfulTheme) async throws -> String {
        let posts = try await forumsClient.loadPosts(for: thread, page: page)
        
        let template = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <style>
                \(theme.css.postCSS)
            </style>
        </head>
        <body>
            \(renderPosts(posts))
        </body>
        </html>
        """
        
        return template
    }
    
    private func renderPosts(_ posts: [Post]) -> String {
        return posts.map { post in
            """
            <div class="post" data-post-id="\(post.id)">
                <div class="post-header">
                    <span class="author">\(post.author)</span>
                    <span class="date">\(post.date)</span>
                </div>
                <div class="post-content">
                    \(post.content)
                </div>
            </div>
            """
        }.joined(separator: "\n")
    }
    
    func selectPost(id: String) {
        selectedPostId = id
        // Additional post selection logic
    }
    
    func openLink(_ href: String) {
        currentLink = href
        showingLinkSheet = true
    }
}
```

### Phase 2: Posts View Container

Create SwiftUI container for posts:

```swift
// New PostsView.swift
struct PostsView: View {
    let thread: Thread
    
    @State private var currentPage = 1
    @State private var isLoading = false
    @State private var showingCompose = false
    @StateObject private var webViewManager = WebViewManager()
    
    var body: some View {
        VStack(spacing: 0) {
            // Web view content
            PostsWebView(
                thread: thread,
                currentPage: $currentPage,
                isLoading: $isLoading
            )
            .environmentObject(webViewManager)
            
            // Custom toolbar
            PostsToolbar(
                thread: thread,
                currentPage: $currentPage,
                showingCompose: $showingCompose
            )
        }
        .navigationTitle(thread.title ?? "Thread")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingCompose) {
            ComposeView(thread: thread)
        }
        .sheet(isPresented: $webViewManager.showingLinkSheet) {
            if let link = webViewManager.currentLink {
                LinkPreviewView(url: link)
            }
        }
        .overlay(alignment: .center) {
            if isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}

// Custom toolbar for posts
struct PostsToolbar: View {
    let thread: Thread
    @Binding var currentPage: Int
    @Binding var showingCompose: Bool
    
    @Environment(\.theme) var theme
    
    var body: some View {
        HStack {
            Button(action: previousPage) {
                Image(systemName: "chevron.left")
                    .font(.title2)
            }
            .disabled(currentPage <= 1)
            
            Spacer()
            
            Text("Page \(currentPage)")
                .font(theme.fonts.body)
                .foregroundColor(theme.colors.secondaryText)
            
            Spacer()
            
            Button(action: nextPage) {
                Image(systemName: "chevron.right")
                    .font(.title2)
            }
            
            Button(action: compose) {
                Image(systemName: "square.and.pencil")
                    .font(.title2)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(theme.colors.background)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(theme.colors.separator),
            alignment: .top
        )
    }
    
    private func previousPage() {
        if currentPage > 1 {
            currentPage -= 1
        }
    }
    
    private func nextPage() {
        currentPage += 1
    }
    
    private func compose() {
        showingCompose = true
    }
}
```

### Phase 3: Smilie Keyboard Component

Convert smilie keyboard to SwiftUI:

```swift
// New SmilieKeyboardView.swift
struct SmilieKeyboardView: View {
    @State private var smilies: [Smilie] = []
    @State private var selectedCategory: SmilieCategory = .standard
    @State private var isLoading = false
    
    let onSmilieSelected: (Smilie) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Category picker
            SmilieCategoryPicker(
                selectedCategory: $selectedCategory,
                categories: SmilieCategory.allCases
            )
            
            // Smilie grid
            ScrollView {
                LazyVGrid(columns: gridColumns, spacing: 8) {
                    ForEach(filteredSmilies) { smilie in
                        SmilieButton(smilie: smilie) {
                            onSmilieSelected(smilie)
                        }
                    }
                }
                .padding()
            }
            .background(Color(.systemBackground))
        }
        .frame(height: 220)
        .task {
            await loadSmilies()
        }
        .overlay(alignment: .center) {
            if isLoading {
                ProgressView()
                    .scaleEffect(1.2)
            }
        }
    }
    
    private let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 8)
    
    private var filteredSmilies: [Smilie] {
        smilies.filter { $0.category == selectedCategory }
    }
    
    private func loadSmilies() async {
        isLoading = true
        
        do {
            smilies = try await SmilieService.shared.loadSmilies()
        } catch {
            print("Failed to load smilies: \(error)")
        }
        
        isLoading = false
    }
}

// Smilie category picker
struct SmilieCategoryPicker: View {
    @Binding var selectedCategory: SmilieCategory
    let categories: [SmilieCategory]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(categories, id: \.self) { category in
                    Button(category.displayName) {
                        selectedCategory = category
                    }
                    .font(.caption)
                    .foregroundColor(selectedCategory == category ? .primary : .secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(selectedCategory == category ? .blue.opacity(0.2) : .clear)
                    )
                }
            }
            .padding(.horizontal)
        }
        .frame(height: 32)
        .background(Color(.systemGray6))
    }
}

// Individual smilie button
struct SmilieButton: View {
    let smilie: Smilie
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            AsyncImage(url: URL(string: smilie.imageURL)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                ProgressView()
                    .scaleEffect(0.5)
            }
            .frame(width: 32, height: 32)
        }
        .buttonStyle(SmilieButtonStyle())
    }
}

// Custom button style for smilies
struct SmilieButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(configuration.isPressed ? Color.blue.opacity(0.3) : Color.clear)
            )
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
```

### Phase 4: Compose View Component

Create rich text compose view:

```swift
// New ComposeView.swift
struct ComposeView: View {
    let thread: Thread?
    
    @State private var subject = ""
    @State private var content = ""
    @State private var showingSmilieKeyboard = false
    @State private var isSubmitting = false
    @State private var error: Error?
    
    @Environment(\.dismiss) var dismiss
    @StateObject private var composeManager = ComposeManager()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Subject field (for new threads)
                if thread == nil {
                    TextField("Subject", text: $subject)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding()
                }
                
                // Content editor
                ComposeTextEditor(
                    text: $content,
                    showingSmilieKeyboard: $showingSmilieKeyboard
                )
                
                // Smilie keyboard
                if showingSmilieKeyboard {
                    SmilieKeyboardView { smilie in
                        insertSmilie(smilie)
                    }
                }
                
                // Toolbar
                ComposeToolbar(
                    showingSmilieKeyboard: $showingSmilieKeyboard,
                    onPreview: preview,
                    onSubmit: submit
                )
            }
            .navigationTitle(thread == nil ? "New Thread" : "Reply")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Post") {
                        Task {
                            await submit()
                        }
                    }
                    .disabled(content.isEmpty || isSubmitting)
                }
            }
            .disabled(isSubmitting)
            .overlay(alignment: .center) {
                if isSubmitting {
                    ProgressView("Posting...")
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .alert("Post Error", isPresented: .constant(error != nil)) {
            Button("OK") { error = nil }
        } message: {
            if let error = error {
                Text(error.localizedDescription)
            }
        }
    }
    
    private func insertSmilie(_ smilie: Smilie) {
        content += smilie.text
    }
    
    private func preview() {
        // Show preview of post
    }
    
    private func submit() async {
        isSubmitting = true
        error = nil
        
        do {
            if let thread = thread {
                try await composeManager.submitReply(to: thread, content: content)
            } else {
                try await composeManager.submitNewThread(subject: subject, content: content)
            }
            
            dismiss()
        } catch {
            self.error = error
        }
        
        isSubmitting = false
    }
}

// Text editor with formatting support
struct ComposeTextEditor: View {
    @Binding var text: String
    @Binding var showingSmilieKeyboard: Bool
    
    var body: some View {
        TextEditor(text: $text)
            .font(.body)
            .padding(8)
            .background(Color(.systemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
            .padding()
    }
}

// Compose toolbar
struct ComposeToolbar: View {
    @Binding var showingSmilieKeyboard: Bool
    let onPreview: () -> Void
    let onSubmit: () -> Void
    
    var body: some View {
        HStack {
            Button(action: { showingSmilieKeyboard.toggle() }) {
                Image(systemName: "face.smiling")
                    .font(.title2)
            }
            
            Spacer()
            
            Button("Preview", action: onPreview)
                .font(.body)
            
            Button("Post", action: onSubmit)
                .font(.body)
                .fontWeight(.medium)
        }
        .padding()
        .background(Color(.systemGray6))
    }
}
```

### Phase 5: Profile View Component

Create user profile view:

```swift
// New ProfileView.swift
struct ProfileView: View {
    let user: User
    
    @State private var userProfile: UserProfile?
    @State private var isLoading = false
    @State private var error: Error?
    
    @StateObject private var profileManager = ProfileManager()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Profile header
                    ProfileHeader(user: user, profile: userProfile)
                    
                    // Profile sections
                    if let profile = userProfile {
                        ProfileSections(profile: profile)
                    }
                }
                .padding()
            }
            .navigationTitle(user.username)
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                await loadProfile()
            }
            .overlay(alignment: .center) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.2)
                }
            }
        }
        .task {
            await loadProfile()
        }
        .alert("Profile Error", isPresented: .constant(error != nil)) {
            Button("OK") { error = nil }
        } message: {
            if let error = error {
                Text(error.localizedDescription)
            }
        }
    }
    
    private func loadProfile() async {
        isLoading = true
        error = nil
        
        do {
            userProfile = try await profileManager.loadProfile(for: user)
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
}

// Profile header component
struct ProfileHeader: View {
    let user: User
    let profile: UserProfile?
    
    var body: some View {
        HStack {
            // Avatar
            AsyncImage(url: URL(string: user.avatarURL ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(systemName: "person.crop.circle")
                    .font(.largeTitle)
                    .foregroundColor(.gray)
            }
            .frame(width: 80, height: 80)
            .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(user.username)
                    .font(.title2)
                    .fontWeight(.bold)
                
                if let title = profile?.title {
                    Text(title)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                if let joinDate = profile?.joinDate {
                    Text("Joined \(joinDate, style: .date)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// Profile sections
struct ProfileSections: View {
    let profile: UserProfile
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ProfileSection(title: "Statistics") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Posts: \(profile.postCount)")
                    Text("Threads: \(profile.threadCount)")
                    Text("Reputation: \(profile.reputation)")
                }
            }
            
            if let bio = profile.bio, !bio.isEmpty {
                ProfileSection(title: "Biography") {
                    Text(bio)
                        .font(.body)
                }
            }
            
            if let location = profile.location, !location.isEmpty {
                ProfileSection(title: "Location") {
                    Text(location)
                        .font(.body)
                }
            }
        }
    }
}

// Profile section component
struct ProfileSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            content
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}
```

## Migration Steps

### Step 1: Web View Components (Week 1-2)
1. **Create PostsWebView**: UIViewRepresentable web view
2. **Implement WebViewManager**: Data and action management
3. **Add JavaScript Integration**: Custom interactions
4. **Test Web View Functionality**: Posts display and interaction

### Step 2: Compose Components (Week 2-3)
1. **Create ComposeView**: Rich text editing interface
2. **Implement SmilieKeyboard**: Custom keyboard component
3. **Add Formatting Support**: Text formatting tools
4. **Test Compose Functionality**: Post creation and editing

### Step 3: Profile Components (Week 3)
1. **Create ProfileView**: User profile display
2. **Implement Profile Sections**: Modular profile components
3. **Add Avatar Support**: Image loading and display
4. **Test Profile Functionality**: User information display

### Step 4: Custom Controls (Week 4)
1. **Create Custom Buttons**: Specialized button components
2. **Implement Progress Indicators**: Loading states
3. **Add Animation Support**: Smooth transitions
4. **Test Custom Controls**: Interactive elements

## Custom Component Patterns

### Reusable Components
```swift
// Generic loading overlay
struct LoadingOverlay: View {
    let isLoading: Bool
    let message: String?
    
    var body: some View {
        Group {
            if isLoading {
                VStack {
                    ProgressView()
                        .scaleEffect(1.2)
                    
                    if let message = message {
                        Text(message)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                    }
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}

// Generic error display
struct ErrorView: View {
    let error: Error
    let onRetry: () -> Void
    
    var body: some View {
        VStack {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)
            
            Text("Something went wrong")
                .font(.headline)
                .padding(.top)
            
            Text(error.localizedDescription)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Retry", action: onRetry)
                .padding(.top)
        }
        .padding()
    }
}
```

### Component Composition
```swift
// Composable view wrapper
struct ComponentWrapper<Content: View>: View {
    let title: String
    let isLoading: Bool
    let error: Error?
    let onRetry: () -> Void
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack {
            if let error = error {
                ErrorView(error: error, onRetry: onRetry)
            } else {
                content
            }
        }
        .overlay(
            LoadingOverlay(isLoading: isLoading, message: nil)
        )
        .navigationTitle(title)
    }
}
```

## Risk Mitigation

### High-Risk Areas
1. **Web View Integration**: JavaScript bridge complexity
2. **Custom Keyboard**: Input method coordination
3. **Rich Text Editing**: Text formatting and input
4. **Performance**: Complex UI components

### Mitigation Strategies
1. **Incremental Testing**: Test each component individually
2. **Performance Monitoring**: Monitor memory and CPU usage
3. **User Testing**: Validate component usability
4. **Fallback Options**: Provide simpler alternatives

## Testing Strategy

### Unit Tests
```swift
// WebViewManagerTests.swift
class WebViewManagerTests: XCTestCase {
    var webViewManager: WebViewManager!
    
    override func setUp() {
        webViewManager = WebViewManager()
    }
    
    func testPostSelection() {
        webViewManager.selectPost(id: "12345")
        
        XCTAssertEqual(webViewManager.selectedPostId, "12345")
    }
    
    func testLinkOpening() {
        webViewManager.openLink("https://example.com")
        
        XCTAssertTrue(webViewManager.showingLinkSheet)
        XCTAssertEqual(webViewManager.currentLink, "https://example.com")
    }
}
```

### Integration Tests
```swift
// ComponentIntegrationTests.swift
class ComponentIntegrationTests: XCTestCase {
    func testPostsViewIntegration() {
        // Test complete posts view functionality
        // Web view loading, toolbar actions, compose integration
    }
    
    func testSmilieKeyboardIntegration() {
        // Test smilie keyboard with compose view
        // Smilie selection, text insertion, keyboard dismissal
    }
}
```

## Performance Considerations

### Memory Management
- Use `@StateObject` for component managers
- Implement proper cleanup in UIViewRepresentable
- Release web view resources properly

### Rendering Performance
- Use lazy loading for large collections
- Implement view recycling where appropriate
- Optimize image loading and caching

### JavaScript Performance
- Minimize JavaScript execution
- Use efficient DOM manipulation
- Implement proper script cleanup

## Timeline Estimation

### Conservative Estimate: 4 weeks
- **Week 1-2**: Web view components
- **Week 2-3**: Compose components  
- **Week 3**: Profile components
- **Week 4**: Custom controls and polish

### Aggressive Estimate: 3 weeks
- Assumes simpler component requirements
- Minimal custom functionality
- No major performance optimization

## Dependencies

### Internal Dependencies
- WebViewManager: Web view coordination
- ComposeManager: Post composition
- ProfileManager: User profile data

### External Dependencies
- WebKit: Web view functionality
- SwiftUI: UI framework
- Combine: Reactive programming

## Success Criteria

### Functional Requirements
- [ ] All custom components work identically
- [ ] Web view interactions work correctly
- [ ] Compose functionality works properly
- [ ] Profile display works correctly
- [ ] Custom controls respond properly

### Technical Requirements
- [ ] No memory leaks in custom components
- [ ] Efficient rendering performance
- [ ] Proper state management
- [ ] Thread-safe operations
- [ ] Proper cleanup on dismissal

### User Experience Requirements
- [ ] Smooth animations and transitions
- [ ] Responsive component interactions
- [ ] Consistent visual design
- [ ] Accessible to VoiceOver users
- [ ] Intuitive component behavior

## Migration Checklist

### Pre-Migration
- [ ] Review all custom components
- [ ] Identify component dependencies
- [ ] Document component behaviors
- [ ] Prepare test scenarios

### During Migration
- [ ] Convert web view components
- [ ] Implement compose components
- [ ] Create profile components
- [ ] Add custom controls
- [ ] Test component integration

### Post-Migration
- [ ] Verify all component functionality
- [ ] Test component performance
- [ ] Validate user interactions
- [ ] Update documentation
- [ ] Deploy to beta testing

This migration guide provides a comprehensive approach to converting all custom components while maintaining functionality and user experience.