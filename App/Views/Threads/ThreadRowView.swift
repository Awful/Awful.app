//  ThreadRowView.swift
//
//  Copyright 2025 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import CoreData
import AwfulCore
import AwfulSettings
import AwfulTheming
import Nuke
import NukeExtensions
import SwiftUI
import UIKit

struct ThreadRowView: View {
    let viewModel: ThreadRowViewModel
    let onTap: () -> Void
    let onBookmarkToggle: () -> Void
    let thread: AwfulThread?
    
    @SwiftUI.Environment(\.theme) private var theme
    @State private var tagImage: UIImage?
    @State private var secondaryTagImage: UIImage?
    @State private var tagImageTask: ImageTask?
    @State private var secondaryTagImageTask: ImageTask?
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                // Tag and rating images
                if viewModel.showTagAndRating {
                    VStack(spacing: 2) {
                        // Tag image
                        if let tagImage = tagImage {
                            Image(uiImage: tagImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 40, height: 40)
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                                .overlay(alignment: .topTrailing) {
                                    // Secondary tag overlay
                                    if let secondaryTagImage = secondaryTagImage {
                                        Image(uiImage: secondaryTagImage)
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 14, height: 14)
                                            .offset(x: 2, y: -2)
                                    }
                                }
                        } else {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.clear)
                                .frame(width: 40, height: 40)
                        }
                        
                        // Rating image
                        if let ratingImage = viewModel.ratingImage {
                            Image(uiImage: ratingImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: 12)
                        }
                    }
                    .frame(width: 46)
                }
                
                // Text content
                VStack(alignment: .leading, spacing: 2) {
                    // Title
                    Text(viewModel.title)
                        .font(Font(viewModel.titleFont))
                        .foregroundColor(viewModel.titleColor)
                        .multilineTextAlignment(.leading)
                        .lineLimit(nil)
                    
                    // Page count, page icon, post info
                    HStack(spacing: 2) {
                        // Page count
                        Text(viewModel.pageCount)
                            .font(Font(viewModel.pageCountFont))
                            .foregroundColor(viewModel.pageCountColor)
                        
                        // Page icon
                        Image("page")
                            .renderingMode(.template)
                            .foregroundColor(viewModel.pageIconColor)
                            .frame(width: 9, height: 12)
                        
                        // Post info
                        Text(viewModel.postInfo)
                            .font(Font(viewModel.postInfoFont))
                            .foregroundColor(viewModel.postInfoColor)
                            .lineLimit(1)
                        
                        Spacer()
                    }
                }
                
                Spacer()
                
                // Unread count
                if !viewModel.unreadCount.isEmpty {
                    Text(viewModel.unreadCount)
                        .font(Font(viewModel.unreadCountFont))
                        .foregroundColor(viewModel.unreadCountColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(viewModel.unreadCountColor.opacity(0.2))
                        )
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .frame(minHeight: 72)
            .background(viewModel.backgroundColor)
            .overlay(alignment: .topTrailing) {
                // Sticky indicator
                if let stickyImage = viewModel.stickyImage {
                    Image(uiImage: stickyImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20, height: 20)
                }
            }
        }
        .buttonStyle(ThreadRowButtonStyle(selectedBackgroundColor: viewModel.selectedBackgroundColor))
        .onAppear {
            loadTagImages()
        }
        .onChange(of: viewModel.tagImageName) { _ in
            loadTagImages()
        }
        .onDisappear {
            tagImageTask?.cancel()
            secondaryTagImageTask?.cancel()
        }
        .contextMenu {
            if let thread = thread {
                BookmarkThreadContextMenu(
                    thread: thread,
                    onBookmarkToggle: onBookmarkToggle,
                    onJumpToFirstPage: { jumpToPage(.first) },
                    onJumpToLastPage: { jumpToPage(.last) }
                )
            } else {
                ThreadContextMenu(
                    onBookmarkToggle: onBookmarkToggle
                )
            }
        }
    }
    
    private func jumpToPage(_ page: ThreadPage) {
        guard let thread = thread else { return }
        
        let threadDestination = ThreadDestination(
            thread: thread,
            page: page,
            author: nil,
            scrollFraction: nil,
            jumpToPostID: nil
        )
        NotificationCenter.default.post(name: Notification.Name("NavigateToThread"), object: threadDestination)
    }
    
    private func loadTagImages() {
        // Cancel any existing tasks
        tagImageTask?.cancel()
        secondaryTagImageTask?.cancel()
        
        // Load main tag image
        if let tagImageName = viewModel.tagImageName {
            tagImageTask = ThreadTagLoader.shared.loadImage(named: tagImageName) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let response):
                        self.tagImage = response.image
                    case .failure:
                        // Use placeholder if available
                        self.tagImage = viewModel.tagImagePlaceholder?.image
                    }
                }
            }
        } else {
            // Use placeholder if no tag image name
            tagImage = viewModel.tagImagePlaceholder?.image
        }
        
        // Load secondary tag image
        if let secondaryTagImageName = viewModel.secondaryTagImageName {
            secondaryTagImageTask = ThreadTagLoader.shared.loadImage(named: secondaryTagImageName) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let response):
                        self.secondaryTagImage = response.image
                    case .failure:
                        self.secondaryTagImage = nil
                    }
                }
            }
        } else {
            secondaryTagImage = nil
        }
    }
}

struct ThreadRowButtonStyle: ButtonStyle {
    let selectedBackgroundColor: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                configuration.isPressed ? selectedBackgroundColor : Color.clear
            )
    }
}

struct ThreadContextMenu: View {
    let onBookmarkToggle: () -> Void
    
    var body: some View {
        Button(action: onBookmarkToggle) {
            Label("Toggle Bookmark", systemImage: "bookmark")
        }
    }
}

struct BookmarkThreadContextMenu: View {
    let thread: AwfulThread
    let onBookmarkToggle: () -> Void
    let onJumpToFirstPage: () -> Void
    let onJumpToLastPage: () -> Void
    
    @State private var showingBookmarkColorPicker = false
    
    var body: some View {
        Group {
            Button(action: onJumpToFirstPage) {
                Label {
                    Text("Jump to First Page")
                } icon: {
                    Image("jump-to-first-page")
                        .renderingMode(.template)
                }
            }
            
            Button(action: onJumpToLastPage) {
                Label {
                    Text("Last Page")
                } icon: {
                    Image("jump-to-last-page")
                        .renderingMode(.template)
                }
            }
            
            if thread.author != nil {
                Button(action: { showAuthorProfile() }) {
                    Label {
                        Text("Author Profile")
                    } icon: {
                        Image("user-profile")
                            .renderingMode(.template)
                    }
                }
            }
            
            Button(action: { copyURL() }) {
                Label {
                    Text("Copy URL")
                } icon: {
                    Image("copy-url")
                        .renderingMode(.template)
                }
            }
            
            Button(action: { copyTitle() }) {
                Label {
                    Text("Copy Title")
                } icon: {
                    Image("copy-title")
                        .renderingMode(.template)
                }
            }
            
            if thread.beenSeen {
                Button(action: { markThreadUnread() }) {
                    Label {
                        Text("Mark Unread")
                    } icon: {
                        Image("mark-as-unread")
                            .renderingMode(.template)
                    }
                }
            } else {
                Button(action: { markThreadRead() }) {
                    Label {
                        Text("Mark Thread As Read")
                    } icon: {
                        Image("mark-read-up-to-here")
                            .renderingMode(.template)
                    }
                }
            }
            
            Button(action: { showingBookmarkColorPicker = true }) {
                Label {
                    Text("Set Color")
                } icon: {
                    Image("rainbow")
                        .renderingMode(.template)
                }
            }
            
            Button(action: onBookmarkToggle) {
                Label {
                    Text(thread.bookmarked ? "Remove Bookmark" : "Add Bookmark")
                } icon: {
                    Image(thread.bookmarked ? "remove-bookmark" : "add-bookmark")
                        .renderingMode(.template)
                }
            }
            .foregroundColor(thread.bookmarked ? .red : .primary)
        }
        .sheet(isPresented: $showingBookmarkColorPicker) {
            BookmarkColorPicker(
                setBookmarkColor: ForumsClient.shared.setBookmarkColor(_:as:),
                thread: thread
            )
            .presentationDetents([.medium])
        }
    }
    
    private func showAuthorProfile() {
        guard let author = thread.author else { return }
        NotificationCenter.default.post(name: Notification.Name("ShowAuthorProfile"), object: author)
    }
    
    private func copyURL() {
        let url = AwfulRoute.threadPage(
            threadID: thread.threadID,
            page: .first,
            .noseen
        ).httpURL
        @FoilDefaultStorageOptional(Settings.lastOfferedPasteboardURLString) var lastOfferedPasteboardURLString
        lastOfferedPasteboardURLString = url.absoluteString
        UIPasteboard.general.coercedURL = url
    }
    
    private func copyTitle() {
        UIPasteboard.general.string = thread.title
    }
    
    private func markThreadRead() {
        Task {
            do {
                _ = try await ForumsClient.shared.listPosts(
                    in: thread,
                    writtenBy: nil,
                    page: .last,
                    updateLastReadPost: true
                )
            } catch {
                print("Error marking thread as read: \(error)")
            }
        }
    }
    
    private func markThreadUnread() {
        let oldSeen = thread.seenPosts
        thread.seenPosts = 0
        Task {
            do {
                try await ForumsClient.shared.markUnread(thread)
            } catch {
                thread.seenPosts = oldSeen
                print("Error marking thread as unread: \(error)")
            }
        }
    }
}


struct ThreadRowView_Previews: PreviewProvider {
    static var previews: some View {
        ThreadRowView(
            viewModel: ThreadRowViewModel.empty,
            onTap: {},
            onBookmarkToggle: {},
            thread: nil
        )
        .themed()
    }
}
