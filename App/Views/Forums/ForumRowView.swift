//  ForumRowView.swift
//
//  Copyright 2025 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import AwfulSettings
import AwfulTheming
import SwiftUI
import CoreData

struct ForumRowView: View {
    let item: ForumItem
    let isEditing: Bool
    let onTap: () -> Void
    let onToggleFavorite: () -> Void
    let onToggleExpansion: () -> Void
    let isInFavorites: Bool
    
    @SwiftUI.Environment(\.theme) private var theme
    @FoilDefaultStorage(Settings.enableHaptics) private var enableHaptics
    
    // Performance optimization: cache computed values
    private let displayName: String
    private let indentationLevel: Int
    private let shouldShowExpansion: Bool
    private let favoriteStarState: FavoriteStarState
    
    init(item: ForumItem, isEditing: Bool, isInFavorites: Bool = false, onTap: @escaping () -> Void, onToggleFavorite: @escaping () -> Void, onToggleExpansion: @escaping () -> Void) {
        self.item = item
        self.isEditing = isEditing
        self.isInFavorites = isInFavorites
        self.onTap = onTap
        self.onToggleFavorite = onToggleFavorite
        self.onToggleExpansion = onToggleExpansion
        
        // Pre-compute values to avoid repeated calculations during render
        switch item {
        case .announcement(let announcement):
            self.displayName = announcement.title
            self.indentationLevel = 0
            self.shouldShowExpansion = false
            self.favoriteStarState = announcement.hasBeenSeen ? .hidden : .visible(selected: true)
        case .forum(let forum):
            self.displayName = forum.name ?? ""
            self.indentationLevel = forum.ancestors.reduce(0) { i, _ in i + 1 }
            // Don't show expansion in favorites section, even if forum has children
            self.shouldShowExpansion = !forum.childForums.isEmpty && !isInFavorites
            // Always show star for forums - filled if favorite, empty if not
            self.favoriteStarState = .visible(selected: forum.metadata.favorite)
        }
    }
    
    private enum FavoriteStarState {
        case hidden
        case visible(selected: Bool)
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Favorite star
            favoriteStarView
                .frame(width: isEditing ? 0 : 38)
                .opacity(isEditing ? 0 : 1)
                .animation(.default, value: isEditing)
            
            // Forum name with indentation
            HStack(spacing: 8) {
                // Indentation
                if indentationLevel > 0 {
                    Spacer()
                        .frame(width: CGFloat(indentationLevel) * 15)
                }
                
                // Forum name
                forumNameView
                
                Spacer()
            }
            
            // Expansion button
            expansionButtonView
                .frame(width: isEditing ? 0 : 44)
                .opacity(isEditing ? 0 : 1)
                .animation(.default, value: isEditing)
        }
        .padding(.horizontal, 16)  // Add internal padding for better visual spacing
        .padding(.vertical, 8)     // Add vertical padding
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .listRowBackground(backgroundColor)
        .listRowSeparatorTint(theme[color: "listSeparatorColor"] ?? Color.gray)
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
    }
    
    @ViewBuilder
    private var favoriteStarView: some View {
        Button(action: {
            if enableHaptics {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
            onToggleFavorite()
        }) {
            Image(favoriteStarImageName)
                .foregroundColor(theme[color: "favoriteStarTintColor"] ?? Color.blue)
        }
        .buttonStyle(PlainButtonStyle())
        .opacity(favoriteStarOpacity)
    }
    
    @ViewBuilder
    private var forumNameView: some View {
        Text(displayName)
            .font(.preferredFont(forTextStyle: .body, fontName: theme["listFontName"], weight: .regular))
            .foregroundColor(theme[color: "listTextColor"] ?? Color.primary)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    @ViewBuilder
    private var expansionButtonView: some View {
        if shouldShowExpansion {
            Button(action: {
                if enableHaptics {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
                onToggleExpansion()
            }) {
                Image(expansionImageName)
                    .foregroundColor(theme[color: "expansionTintColor"] ?? Color.blue)
                    .rotationEffect(.degrees(isExpanded ? 0 : -90))
                    .animation(.easeInOut(duration: 0.2), value: isExpanded)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    // MARK: - Computed Properties
    
    private var favoriteStarImageName: String {
        switch favoriteStarState {
        case .hidden:
            return "star-off"
        case .visible(let selected):
            return selected ? "star-on" : "star-off"
        }
    }
    
    private var favoriteStarOpacity: Double {
        switch favoriteStarState {
        case .hidden:
            return 0
        case .visible:
            return 1
        }
    }
    
    private var expansionImageName: String {
        return "forum-arrow-down"
    }
    
    private var isExpanded: Bool {
        guard case .forum(let forum) = item else { return false }
        return forum.metadata.showsChildrenInForumList
    }
    
    private var backgroundColor: Color {
        theme[color: "listBackgroundColor"] ?? Color.white
    }
}

// MARK: - Custom Button Style (removed - no longer needed)

// MARK: - Font Extension

extension Font {
    static func preferredFont(forTextStyle style: UIFont.TextStyle, fontName: String?, weight: UIFont.Weight) -> Font {
        let uiFont = UIFont.preferredFontForTextStyle(style, fontName: fontName, sizeAdjustment: 0, weight: weight)
        return Font(uiFont)
    }
}

// MARK: - Preview

struct ForumRowView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Mock forum item
            ForumRowView(
                item: .forum(createMockForum()),
                isEditing: false,
                isInFavorites: false,
                onTap: {},
                onToggleFavorite: {},
                onToggleExpansion: {}
            )
            
            // Mock announcement item
            ForumRowView(
                item: .announcement(createMockAnnouncement()),
                isEditing: false,
                isInFavorites: false,
                onTap: {},
                onToggleFavorite: {},
                onToggleExpansion: {}
            )
        }
        .themed()
        .previewLayout(.sizeThatFits)
    }
    
    private static func createMockForum() -> Forum {
        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        let forum = Forum(context: context)
        forum.name = "General Discussion"
        return forum
    }
    
    private static func createMockAnnouncement() -> Announcement {
        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        let announcement = Announcement(context: context)
        announcement.title = "Important Site Update"
        return announcement
    }
}
