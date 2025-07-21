import SwiftUI
import AwfulCore
import AwfulTheming
import AwfulSettings
import CoreData

/// A liquid glass wrapper around PostsToolbarContainer that provides modern iOS 26+ visual effects
@available(iOS 26.0, *)
struct LiquidGlassBottomBar: View {
    // MARK: - Properties
    let thread: AwfulThread
    let author: User?
    let page: ThreadPage?
    let numberOfPages: Int
    let isLoadingViewVisible: Bool
    
    // MARK: - Action Callbacks
    let onSettingsTapped: () -> Void
    let onBackTapped: () -> Void
    let onForwardTapped: () -> Void
    let onPageSelected: (ThreadPage) -> Void
    let onGoToLastPost: () -> Void
    let onBookmarkTapped: () -> Void
    let onCopyLinkTapped: () -> Void
    let onVoteTapped: () -> Void
    let onYourPostsTapped: () -> Void
    
    // MARK: - Environment
    @SwiftUI.Environment(\.theme) private var theme
    @FoilDefaultStorage(Settings.enableLiquidGlass) private var enableLiquidGlass
    @State private var showingPagePicker = false
    
    // MARK: - Body
    var body: some View {
        if enableLiquidGlass {
            liquidGlassContent
        } else {
            regularContent
        }
    }
    
    // MARK: - Liquid Glass Content
    @ViewBuilder
    private var liquidGlassContent: some View {
        // Liquid glass content for overlay use (immersive mode)
        HStack(spacing: 12) {
            // Settings button
            Button(action: onSettingsTapped) {
                Image("page-settings")
                    .renderingMode(.template)
                    .foregroundColor(toolbarTextColor)
            }
            .accessibilityLabel("Settings")
            
            Spacer()
            
            // Back button - only show when enabled for morphing effect
            if isBackEnabled {
                Button(action: onBackTapped) {
                    Image("arrowleft")
                        .renderingMode(.template)
                        .foregroundColor(toolbarTextColor)
                }
                .accessibilityLabel("Previous page")
                .padding(.leading, 4)
            }
            
            // Page selector button
            Button(action: {
                guard case .specific = page else { return }
                showingPagePicker = true
            }) {
                if case .specific(let pageNumber) = page, numberOfPages > 0 {
                    HStack(alignment: .top, spacing: 0) {
                        VStack(spacing: 0) {
                            Text("\(pageNumber)")
                                .font(.footnote.weight(.medium))
                                .foregroundColor(toolbarTextColor)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            Text("\(numberOfPages)")
                                .font(.footnote.weight(.medium))
                                .foregroundColor(toolbarTextColor)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        Text(" /")
                            .font(.footnote.weight(.medium))
                            .foregroundColor(toolbarTextColor)
                    }
                    .frame(minWidth: 30)
                } else {
                    Text("...")
                        .font(.body.weight(.medium))
                        .foregroundColor(toolbarTextColor)
                        .frame(minWidth: 60)
                }
            }
            .padding(.trailing, 8) // Add right padding to page picker
            .disabled(page == nil)
            .accessibilityLabel(currentPageAccessibilityLabel)
            .accessibilityHint("Opens page picker")
            .popover(isPresented: $showingPagePicker) {
                PostsPagePicker(
                    thread: thread,
                    numberOfPages: numberOfPages,
                    currentPage: currentPageNumber,
                    onPageSelected: onPageSelected,
                    onGoToLastPost: onGoToLastPost
                )
                .presentationCompactAdaptation(.popover)
            }
            .padding(.trailing, isForwardEnabled ? 4 : 0) // Dynamic spacing based on forward button presence
            
            // Forward button - only show when enabled for morphing effect
            if isForwardEnabled {
                Button(action: onForwardTapped) {
                    Image("arrowright")
                        .renderingMode(.template)
                        .foregroundColor(toolbarTextColor)
                }
                .accessibilityLabel("Next page")
            }
            
            Spacer()
            
            // Menu button
            Menu {
                // Bookmark
                Button(action: onBookmarkTapped) {
                    Label(
                        thread.bookmarked ? "Remove Bookmark" : "Bookmark Thread",
                        image: thread.bookmarked ? "remove-bookmark" : "add-bookmark"
                    )
                }
                .foregroundColor(thread.bookmarked ? .red : .primary)
                
                // Copy link
                Button(action: onCopyLinkTapped) {
                    Label("Copy link", image: "copy-url")
                }
                
                // Vote
                Button(action: onVoteTapped) {
                    Label("Vote", image: "vote")
                }
                
                // Your posts
                Button(action: onYourPostsTapped) {
                    Label("Your posts", image: "single-users-posts")
                }
            } label: {
                Image("steamed-ham")
                    .renderingMode(.template)
                    .foregroundColor(toolbarTextColor)
            }
            .accessibilityLabel("Menu")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(minHeight: 44) // Standard toolbar height
        .background(Color(theme[uicolor: "tabBarBackgroundColor"] ?? UIColor.systemBackground))
        .overlay(
            Rectangle()
                .fill(Color(theme[uicolor: "bottomBarTopBorderColor"] ?? UIColor.separator))
                .frame(height: 0.5),
            alignment: .top
        )
    }
    
    // MARK: - Toolbar Content for Parent View
    /// Returns the toolbar content to be applied by the parent view in its navigation context
    @ToolbarContentBuilder
    static func toolbarContent(
        thread: AwfulThread,
        page: ThreadPage?,
        numberOfPages: Int,
        showingPagePicker: Binding<Bool>,
        toolbarTextColor: Color,
        roundedFonts: Bool,
        isBackEnabled: Bool,
        isForwardEnabled: Bool,
        currentPageAccessibilityLabel: String,
        onSettingsTapped: @escaping () -> Void,
        onBackTapped: @escaping () -> Void,
        onForwardTapped: @escaping () -> Void,
        onPageSelected: @escaping (ThreadPage) -> Void,
        onGoToLastPost: @escaping () -> Void,
        onBookmarkTapped: @escaping () -> Void,
        onCopyLinkTapped: @escaping () -> Void,
        onVoteTapped: @escaping () -> Void,
        onYourPostsTapped: @escaping () -> Void
    ) -> some ToolbarContent {
        ToolbarItemGroup(placement: .bottomBar) {
            // Settings button
            Button(action: onSettingsTapped) {
                Image("page-settings")
                    .renderingMode(.template)
                    .foregroundColor(toolbarTextColor)
            }
            .accessibilityLabel("Settings")
            
            Spacer()
            
            // Navigation controls with iOS 26 morphing
            NavigationControlsContainer(
                page: page,
                numberOfPages: numberOfPages,
                showingPagePicker: showingPagePicker,
                toolbarTextColor: toolbarTextColor,
                roundedFonts: roundedFonts,
                isBackEnabled: isBackEnabled,
                isForwardEnabled: isForwardEnabled,
                currentPageAccessibilityLabel: currentPageAccessibilityLabel,
                thread: thread,
                onBackTapped: onBackTapped,
                onForwardTapped: onForwardTapped,
                onPageSelected: onPageSelected,
                onGoToLastPost: onGoToLastPost
            )
            
            Spacer()
            
            // Menu button
            Menu {
                // Bookmark
                Button(action: onBookmarkTapped) {
                    Label(
                        thread.bookmarked ? "Remove Bookmark" : "Bookmark Thread",
                        image: thread.bookmarked ? "remove-bookmark" : "add-bookmark"
                    )
                }
                .foregroundColor(thread.bookmarked ? .red : .primary)
                
                // Copy link
                Button(action: onCopyLinkTapped) {
                    Label("Copy link", image: "copy-url")
                }
                
                // Vote
                Button(action: onVoteTapped) {
                    Label("Vote", image: "vote")
                }
                
                // Your posts
                Button(action: onYourPostsTapped) {
                    Label("Your posts", image: "single-users-posts")
                }
            } label: {
                Image("steamed-ham")
                    .renderingMode(.template)
                    .foregroundColor(toolbarTextColor)
            }
            .accessibilityLabel("Menu")
        }
    }
    
    // MARK: - Regular Content
    private var regularContent: some View {
        PostsToolbarContainer(
            thread: thread,
            author: author,
            page: page,
            numberOfPages: numberOfPages,
            isLoadingViewVisible: isLoadingViewVisible,
            onSettingsTapped: onSettingsTapped,
            onBackTapped: onBackTapped,
            onForwardTapped: onForwardTapped,
            onPageSelected: onPageSelected,
            onGoToLastPost: onGoToLastPost,
            onBookmarkTapped: onBookmarkTapped,
            onCopyLinkTapped: onCopyLinkTapped,
            onVoteTapped: onVoteTapped,
            onYourPostsTapped: onYourPostsTapped
        )
        .background(Color(theme[uicolor: "tabBarBackgroundColor"] ?? UIColor.systemBackground))
        .overlay(
            Rectangle()
                .fill(Color(theme[uicolor: "bottomBarTopBorderColor"] ?? UIColor.separator))
                .frame(height: 0.5),
            alignment: .top
        )
    }
    


    // MARK: - Computed Properties
    private var currentPageNumber: Int {
        if case .specific(let pageNumber) = page {
            return pageNumber
        }
        return 1
    }
    
    private var pageIdentifier: String {
        switch page {
        case .specific(let pageNumber):
            return "page-\(pageNumber)"
        case .last:
            return "last"
        case .nextUnread:
            return "nextUnread"
        case .none:
            return "none"
        }
    }
    
    private var isBackEnabled: Bool {
        switch page {
        case .specific(let pageNumber)?:
            return pageNumber > 1
        case .last?, .nextUnread?, nil:
            return false
        }
    }
    
    private var isForwardEnabled: Bool {
        switch page {
        case .specific(let pageNumber)?:
            return pageNumber < numberOfPages
        case .last?, .nextUnread?, nil:
            return false
        }
    }
    
    private var currentPageAccessibilityLabel: String {
        if case .specific(let pageNumber) = page, numberOfPages > 0 {
            return "Page \(pageNumber) of \(numberOfPages)"
        } else {
            return ""
        }
    }
    
    @ViewBuilder
    private var pageNumberView: some View {
        if case .specific(let pageNumber) = page, numberOfPages > 0 {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Text("\(pageNumber)")
                        .font(.body.weight(.medium))
                        .foregroundColor(toolbarTextColor)
                    Text(" /")
                        .font(.body.weight(.medium))
                        .foregroundColor(toolbarTextColor)
                    Spacer()
                }
                HStack(spacing: 0) {
                    Text("\(numberOfPages)")
                        .font(.body.weight(.medium))
                        .foregroundColor(toolbarTextColor)
                    Spacer()
                }
            }
            .frame(minWidth: 60)
        } else {
            Text("...")
                .font(.body.weight(.medium))
                .foregroundColor(toolbarTextColor)
                .frame(minWidth: 60)
        }
    }
    
    private var toolbarTextColor: Color {
        Color(theme[uicolor: "toolbarTextColor"] ?? .systemBlue)
    }
    
    private var disabledToolbarTextColor: Color {
        toolbarTextColor.opacity(0.5)
    }
}

// MARK: - Navigation Controls Container with iOS 26 Morphing
@available(iOS 26.0, *)
private struct NavigationControlsContainer: View {
    let page: ThreadPage?
    let numberOfPages: Int
    let showingPagePicker: Binding<Bool>
    let toolbarTextColor: Color
    let roundedFonts: Bool
    let isBackEnabled: Bool
    let isForwardEnabled: Bool
    let currentPageAccessibilityLabel: String
    let thread: AwfulThread
    let onBackTapped: () -> Void
    let onForwardTapped: () -> Void
    let onPageSelected: (ThreadPage) -> Void
    let onGoToLastPost: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            // Back button - with smooth morphing
            if isBackEnabled {
                Button(action: onBackTapped) {
                    Image("arrowleft")
                        .renderingMode(.template)
                        .foregroundColor(toolbarTextColor)
                }
                .accessibilityLabel("Previous page")
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.8).combined(with: .opacity),
                    removal: .scale(scale: 0.8).combined(with: .opacity)
                ))
            }
            
            // Page selector button - always visible for consistent layout
            Button(action: {
                guard case .specific = page else { return }
                showingPagePicker.wrappedValue = true
            }) {
                if case .specific(let pageNumber) = page, numberOfPages > 0 {
                    HStack(alignment: .top, spacing: 0) {
                        VStack(spacing: 0) {
                            Text("\(pageNumber)")
                                .font(.footnote.weight(.medium))
                                .foregroundColor(toolbarTextColor)
                                .applyFontDesign(if: roundedFonts)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            Text("\(numberOfPages)")
                                .font(.footnote.weight(.medium))
                                .foregroundColor(toolbarTextColor)
                                .applyFontDesign(if: roundedFonts)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        Text(" /")
                            .font(.footnote.weight(.medium))
                            .foregroundColor(toolbarTextColor)
                            .applyFontDesign(if: roundedFonts)
                    }
                    .frame(minWidth: 30)
                } else {
                    Text("...")
                        .font(.body.weight(.medium))
                        .foregroundColor(toolbarTextColor)
                        .frame(minWidth: 60)
                }
            }
            .padding(.trailing, 8) // Add right padding to page picker
            .disabled(page == nil)
            .accessibilityLabel(currentPageAccessibilityLabel)
            .accessibilityHint("Opens page picker")
            .padding(.horizontal, 12)
            .popover(isPresented: showingPagePicker) {
                PostsPagePicker(
                    thread: thread,
                    numberOfPages: numberOfPages,
                    currentPage: {
                        if case .specific(let pageNumber) = page {
                            return pageNumber
                        }
                        return 1
                    }(),
                    onPageSelected: onPageSelected,
                    onGoToLastPost: onGoToLastPost
                )
                .presentationCompactAdaptation(.popover)
            }
            
            // Forward button - with smooth morphing
            if isForwardEnabled {
                Button(action: onForwardTapped) {
                    Image("arrowright")
                        .renderingMode(.template)
                        .foregroundColor(toolbarTextColor)
                }
                .accessibilityLabel("Next page")
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.8).combined(with: .opacity),
                    removal: .scale(scale: 0.8).combined(with: .opacity)
                ))
            }
        }
        .animation(.smooth(duration: 0.8), value: isBackEnabled)
        .animation(.smooth(duration: 0.8), value: isForwardEnabled)
    }
}

// MARK: - Preview
@available(iOS 26.0, *)
#Preview {
    // Create an in-memory Core Data stack for preview
    let container = NSPersistentContainer(name: "AwfulData")
    container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
    
    container.loadPersistentStores { _, _ in }
    
    let context = container.viewContext
    let thread = AwfulThread(context: context)
    thread.title = "Sample Thread Title"
    thread.bookmarked = false
    thread.threadID = "preview-thread-id"
    
    return LiquidGlassBottomBar(
        thread: thread,
        author: nil,
        page: .specific(5),
        numberOfPages: 10,
        isLoadingViewVisible: false,
        onSettingsTapped: { print("Settings tapped") },
        onBackTapped: { print("Back tapped") },
        onForwardTapped: { print("Forward tapped") },
        onPageSelected: { page in print("Page selected: \(page)") },
        onGoToLastPost: { print("Go to last post") },
        onBookmarkTapped: { print("Bookmark tapped") },
        onCopyLinkTapped: { print("Copy link tapped") },
        onVoteTapped: { print("Vote tapped") },
        onYourPostsTapped: { print("Your posts tapped") }
    )
    .environment(\.theme, Theme.defaultTheme(mode: .light))
}
