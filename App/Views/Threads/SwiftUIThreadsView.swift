//  SwiftUIThreadsView.swift
//
//  Copyright 2025 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import AwfulSettings
import AwfulTheming
import CoreData
import Nuke
import SwiftUI

struct SwiftUIThreadsView: View {
    @StateObject private var viewModel: ThreadsListViewModel
    @SwiftUI.Environment(\.theme) private var theme
    @SwiftUI.Environment(\.dismiss) private var dismiss
    @SwiftUI.Environment(\.horizontalSizeClass) private var horizontalSizeClass
    // Removed AwfulNavigationController - using coordinator only
    var coordinator: (any MainCoordinator)?
    
    @State private var showingCompose = false
    @State private var showingTagPicker = false
    @State private var isLoadingMore = false
    @State private var error: Error?
    @State private var showingError = false
    
    private let forum: Forum
    
    init(forum: Forum, managedObjectContext: NSManagedObjectContext, coordinator: (any MainCoordinator)? = nil) {
        self.forum = forum
        self.coordinator = coordinator
        self._viewModel = StateObject(wrappedValue: {
            do {
                return try ThreadsListViewModel(forum: forum, managedObjectContext: managedObjectContext)
            } catch {
                fatalError("Failed to create ThreadsListViewModel: \(error)")
            }
        }())
    }
    
    var body: some View {
        ZStack {
            // Background that extends to safe area
            (theme[color: "navigationBarTintColor"] ?? Color(.systemBackground))
                .ignoresSafeArea(.all, edges: .top)
            
            VStack(spacing: 0) {
                NavigationHeaderView(
                    title: forum.name ?? "Forum",
                    leftButton: HeaderButton(image: "back") {
                        handleBackButtonTap()
                    },
                    rightButton: HeaderButton(image: "compose") {
                        showingCompose = true
                    }
                )
                
                // Filter toolbar
                HStack {
                    Spacer()
                    
                    Button(action: {
                        showingTagPicker = true
                    }) {
                        HStack(spacing: 4) {
                            Text("Filter by Tag")
                                .font(.caption)
                            if let filterTag = viewModel.filterThreadTag {
                                Text("(\(filterTag.imageName ?? "Unknown"))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .foregroundColor(theme[color: "expansionTintColor"] ?? .primary)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(.systemBackground))
                
                threadsList
            }
        }
        .onAppear {
            handleViewAppear()
        }
        .onDisappear {
            handleViewDisappear()
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)) { _ in
            // Handle Core Data context saves if needed
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ShowCompose"))) { _ in
            showingCompose = true
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            if let error = error {
                Text(error.localizedDescription)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ShowAuthorProfile"))) { notification in
            if let author = notification.object as? User {
                showAuthorProfile(author)
            }
        }
        .sheet(isPresented: $showingCompose) {
            ComposeThreadSheet(
                composeViewController: viewModel.createComposeViewController(),
                coordinator: coordinator
            )
        }
        .sheet(isPresented: $showingTagPicker) {
            ThreadTagPickerSheet(
                forum: forum,
                selectedTag: viewModel.filterThreadTag,
                onTagSelected: { tag in
                    viewModel.setFilter(threadTag: tag)
                    showingTagPicker = false
                },
                onDismiss: {
                    showingTagPicker = false
                }
            )
        }
        .navigationBarHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("")
        .modifier(
            UnpopGestureViewModifier(coordinator: coordinator)
        )
        .themed()
    }
    
    private var threadsList: some View {
        List {
            ForEach(viewModel.threads) { threadViewModel in
                ThreadRowView(
                    viewModel: threadViewModel,
                    onTap: {
                        handleThreadTap(threadViewModel)
                    },
                    onBookmarkToggle: {
                        handleBookmarkToggle(threadViewModel)
                    },
                    thread: viewModel.thread(for: threadViewModel)
                )
                .listRowPressEffect {
                    handleThreadTap(threadViewModel)
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 5, bottom: 0, trailing: 5))
                .listRowSeparator(.visible, edges: .bottom)
                .listRowSeparatorTint(Color(theme[uicolor: "listSeparatorColor"] ?? UIColor.separator))
                .background(Color.clear)
            }
            
            // Load more indicator
            if viewModel.canLoadMore && !viewModel.threads.isEmpty {
                LoadMoreView(isLoading: isLoadingMore) {
                    await loadMore()
                }
            }
        }
        .listStyle(.plain)
        .background(backgroundColor)
        .scrollContentBackground(.hidden)
        .refreshable {
            await refresh()
        }
    }
    
    
    private var filterButtonTitle: String {
        if let tag = viewModel.filterThreadTag {
            return "Filtering by \"\(tag.threadTagID ?? "")\" — tap to clear"
        } else {
            return "Filter by Tag"
        }
    }
    
    private var backgroundColor: Color {
        Color(theme[uicolor: "listBackgroundColor"] ?? UIColor.systemBackground)
    }
    
    private func handleViewAppear() {
        // Handle tab bar visibility for iPhone
        if UIDevice.current.userInterfaceIdiom == .phone {
            Task { @MainActor in
                coordinator?.isTabBarHidden = false // Reset to show tab bar at thread list level
            }
        }
        
        // Check if refresh is needed
        let isTimeToRefresh: Bool
        if viewModel.filterThreadTag == nil {
            isTimeToRefresh = RefreshMinder.sharedMinder.shouldRefreshForum(forum)
        } else {
            isTimeToRefresh = RefreshMinder.sharedMinder.shouldRefreshFilteredForum(forum)
        }
        
        if isTimeToRefresh || viewModel.threads.isEmpty {
            Task {
                await refresh()
            }
        }
    }
    
    private func handleViewDisappear() {
        viewModel.undoManager.removeAllActions()
    }
    
    private func handleThreadTap(_ threadViewModel: ThreadRowViewModel) {
        guard let thread = viewModel.thread(for: threadViewModel) else { return }
        
        // Add haptic feedback if enabled
        @FoilDefaultStorage(Settings.enableHaptics) var enableHaptics: Bool
        if enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        
        let page: ThreadPage = thread.anyUnreadPosts ? .nextUnread : .first
        
        // Use coordinator navigation instead of notifications
        if let coordinator = coordinator {
            coordinator.navigateToThread(thread, page: page, author: nil)
        } else {
            // Fallback to notification system for cases where coordinator is not available
            let threadDestination = ThreadDestination(
                thread: thread,
                author: nil,
                page: page,
                scrollFraction: nil,
                jumpToPostID: nil
            )
            NotificationCenter.default.post(name: Notification.Name("NavigateToThread"), object: threadDestination)
        }
    }
    
    private func handleBookmarkToggle(_ threadViewModel: ThreadRowViewModel) {
        guard let thread = viewModel.thread(for: threadViewModel) else { return }
        
        Task {
            do {
                try await viewModel.toggleBookmark(for: thread)
            } catch {
                self.error = error
                self.showingError = true
            }
        }
    }
    
    @MainActor
    private func refresh() async {
        do {
            try await viewModel.refresh()
        } catch {
            self.error = error
            self.showingError = true
        }
    }
    
    @MainActor
    private func loadMore() async {
        isLoadingMore = true
        
        do {
            try await viewModel.loadMore()
        } catch {
            self.error = error
            self.showingError = true
        }
        
        isLoadingMore = false
    }
    
    private func showAuthorProfile(_ author: User) {
        let profile = ProfileViewController(user: author)
        let profileVC: UIViewController
        
        if UIDevice.current.userInterfaceIdiom == .pad {
            profileVC = profile.enclosingNavigationController
        } else {
            profileVC = profile
        }
        
        // Get the current window's root view controller
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            
            var presentingVC = rootVC
            while let presented = presentingVC.presentedViewController {
                presentingVC = presented
            }
            
            if UIDevice.current.userInterfaceIdiom == .pad {
                presentingVC.present(profileVC, animated: true)
            } else {
                if let navController = presentingVC as? UINavigationController {
                    navController.pushViewController(profile, animated: true)
                } else if let navController = presentingVC.navigationController {
                    navController.pushViewController(profile, animated: true)
                } else {
                    // Fallback to modal presentation
                    presentingVC.present(UINavigationController(rootViewController: profile), animated: true)
                }
            }
        }
    }
    
    private func handleBackButtonTap() {
        let isIPad = UIDevice.current.userInterfaceIdiom == .pad
        print("🔙 handleBackButtonTap called, device idiom: \(isIPad ? "iPad" : "iPhone"), horizontalSizeClass: \(horizontalSizeClass == .regular ? "regular" : "compact")")
        
        if isIPad {
            // iPad: Pop from sidebar path to go back to forums list
            if let coordinator = coordinator as? MainCoordinatorImpl {
                print("🔙 iPad: sidebarPath count before: \(coordinator.sidebarPath.count)")
                if !coordinator.sidebarPath.isEmpty {
                    coordinator.sidebarPath.removeLast()
                    print("🔙 iPad: Popped from sidebarPath, remaining count: \(coordinator.sidebarPath.count)")
                } else {
                    print("⚠️ iPad: sidebarPath is empty, cannot go back")
                }
            } else {
                print("⚠️ iPad: coordinator is not MainCoordinatorImpl")
            }
        } else {
            // iPhone: Use coordinator
            print("🔙 iPhone: Using coordinator")
            coordinator?.goBack()
        }
    }
}

// MARK: - Supporting Views

struct LoadMoreView: View {
    let isLoading: Bool
    let loadMore: () async -> Void
    
    var body: some View {
        HStack {
            Spacer()
            
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
            } else {
                Button("Load More") {
                    Task {
                        await loadMore()
                    }
                }
            }
            
            Spacer()
        }
        .padding()
        .onAppear {
            if !isLoading {
                Task {
                    await loadMore()
                }
            }
        }
    }
}

struct ComposeThreadSheet: UIViewControllerRepresentable {
    let composeViewController: ThreadComposeViewController
    let coordinator: (any MainCoordinator)?
    
    func makeUIViewController(context: Context) -> UINavigationController {
        composeViewController.delegate = context.coordinator
        return composeViewController.enclosingNavigationController
    }
    
    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {
        // No updates needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(coordinator: coordinator)
    }
    
    class Coordinator: NSObject, ComposeTextViewControllerDelegate {
        let coordinator: (any MainCoordinator)?
        
        init(coordinator: (any MainCoordinator)?) {
            self.coordinator = coordinator
        }
        
        func composeTextViewController(_ composeTextViewController: ComposeTextViewController, didFinishWithSuccessfulSubmission success: Bool, shouldKeepDraft: Bool) {
            composeTextViewController.dismiss(animated: true) {
                if let thread = (composeTextViewController as? ThreadComposeViewController)?.thread, success {
                    let threadDestination = ThreadDestination(
                        thread: thread,
                        author: nil,
                        page: .first,
                        scrollFraction: nil,
                        jumpToPostID: nil
                    )
                    NotificationCenter.default.post(name: Notification.Name("NavigateToThread"), object: threadDestination)
                }
                
                if !shouldKeepDraft {
                    // Clean up compose view controller
                }
            }
        }
    }
}

struct ThreadTagPickerSheet: UIViewControllerRepresentable {
    let forum: Forum
    let selectedTag: ThreadTag?
    let onTagSelected: (ThreadTag?) -> Void
    let onDismiss: () -> Void
    
    func makeUIViewController(context: Context) -> UINavigationController {
        let imageNames = forum.threadTags.array
            .compactMap { $0 as? ThreadTag }
            .compactMap { $0.imageName }
        
        let picker = ThreadTagPickerViewController(
            firstTag: .noFilter,
            imageNames: imageNames,
            secondaryImageNames: []
        )
        picker.delegate = context.coordinator
        picker.title = LocalizedString("thread-list.filter.picker-title")
        picker.navigationItem.leftBarButtonItem = picker.cancelButtonItem
        picker.selectImageName(selectedTag?.imageName)
        
        return UINavigationController(rootViewController: picker)
    }
    
    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {
        // No updates needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(
            forum: forum,
            onTagSelected: onTagSelected,
            onDismiss: onDismiss
        )
    }
    
    class Coordinator: NSObject, ThreadTagPickerViewControllerDelegate {
        let forum: Forum
        let onTagSelected: (ThreadTag?) -> Void
        let onDismiss: () -> Void
        
        init(forum: Forum, onTagSelected: @escaping (ThreadTag?) -> Void, onDismiss: @escaping () -> Void) {
            self.forum = forum
            self.onTagSelected = onTagSelected
            self.onDismiss = onDismiss
        }
        
        func didSelectImageName(_ imageName: String?, in picker: ThreadTagPickerViewController) {
            let tag: ThreadTag?
            if let imageName = imageName {
                tag = forum.threadTags.array
                    .compactMap { $0 as? ThreadTag }
                    .first { $0.imageName == imageName }
            } else {
                tag = nil
            }
            
            onTagSelected(tag)
            picker.dismiss()
        }
        
        func didSelectSecondaryImageName(_ secondaryImageName: String, in picker: ThreadTagPickerViewController) {
            // Not used for filtering
        }
        
        func didDismissPicker(_ picker: ThreadTagPickerViewController) {
            onDismiss()
        }
        
        func didClearThreadTagFilter(from picker: ThreadTagPickerViewController) {
            onTagSelected(nil)
            picker.dismiss()
        }
    }
}

// MARK: - Helper Views

struct AsyncThreadTagImage: View {
    let imageName: String
    @State private var image: UIImage?
    @State private var imageTask: ImageTask?
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
            }
        }
        .navigationBarHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("")
        .onAppear {
            loadImage()
        }
        .onDisappear {
            imageTask?.cancel()
        }
        .onChange(of: imageName) { _ in
            loadImage()
        }
    }
    
    private func loadImage() {
        imageTask?.cancel()
        
        imageTask = ThreadTagLoader.shared.loadImage(named: imageName) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    self.image = response.image
                case .failure:
                    self.image = nil
                }
            }
        }
    }
}

#Preview {
    // Create a mock managed object context for preview
    let container: NSPersistentContainer = NSPersistentContainer(name: "DataModel")
    let context: NSManagedObjectContext = container.viewContext
    
    let mockForum = Forum(context: context)
    mockForum.name = "General Bullshit"
    mockForum.forumID = "1"
    
    return SwiftUIThreadsView(
        forum: mockForum,
        managedObjectContext: context
    )
    .themed()
}