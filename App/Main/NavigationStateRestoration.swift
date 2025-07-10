//  NavigationStateRestoration.swift
//
//  Copyright 2025 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import SwiftUI
import AwfulCore
import CoreData
import Foundation

// MARK: - Restoration Data Models

/// Represents the complete navigation state that can be restored
struct NavigationState: Codable {
    let selectedTab: MainTab.RawValue
    let isTabBarHidden: Bool
    let mainNavigationPath: [NavigationDestination]
    let sidebarNavigationPath: [NavigationDestination]
    let presentedSheet: PresentedSheetState?
    let navigationHistory: [NavigationDestination]
    let unpopStack: [NavigationDestination]
    let editStates: EditStates
    let interfaceVersion: Int
    
    static let currentInterfaceVersion = 1
}

/// Represents different types of navigation destinations that can be restored
enum NavigationDestination: Codable, Hashable {
    case thread(threadID: String, page: ThreadPage, authorID: String?, scrollFraction: CGFloat?)
    case forum(forumID: String)
    case privateMessage(messageID: String)
    case composePrivateMessage
    case profile(userID: String)
    case rapSheet(userID: String)
    
    // Add more destination types as needed
}

/// Represents sheet presentation state
enum PresentedSheetState: Codable {
    case search
    case compose(MainTab.RawValue)
}

/// Represents edit states for various tabs
struct EditStates: Codable {
    let isEditingBookmarks: Bool
    let isEditingMessages: Bool
    let isEditingForums: Bool
}

/// Extension to make MainTab.RawValue work with restoration
extension MainTab: Codable {
    // MainTab already has String raw value, so it's naturally Codable
}

// MARK: - Navigation State Manager

/// Manages saving and restoring navigation state
class NavigationStateManager: ObservableObject {
    private let stateKey = "AwfulNavigationState"
    private let managedObjectContext: NSManagedObjectContext
    
    init(managedObjectContext: NSManagedObjectContext) {
        self.managedObjectContext = managedObjectContext
    }
    
    /// Saves the current navigation state
    func saveNavigationState(_ state: NavigationState) {
        do {
            let data = try JSONEncoder().encode(state)
            UserDefaults.standard.set(data, forKey: stateKey)
            print("🔄 Navigation state saved successfully")
        } catch {
            print("❌ Failed to save navigation state: \(error)")
        }
    }
    
    /// Restores the navigation state if available and valid
    func restoreNavigationState() -> NavigationState? {
        guard let data = UserDefaults.standard.data(forKey: stateKey) else {
            print("🔄 No saved navigation state found")
            return nil
        }
        
        do {
            let state = try JSONDecoder().decode(NavigationState.self, from: data)
            
            // Check interface version compatibility
            guard state.interfaceVersion == NavigationState.currentInterfaceVersion else {
                print("🔄 Navigation state version mismatch, skipping restoration")
                clearNavigationState()
                return nil
            }
            
            print("🔄 Navigation state restored successfully")
            return state
        } catch {
            print("❌ Failed to restore navigation state: \(error)")
            clearNavigationState()
            return nil
        }
    }
    
    /// Clears the saved navigation state
    func clearNavigationState() {
        UserDefaults.standard.removeObject(forKey: stateKey)
        print("🔄 Navigation state cleared")
    }
}

// MARK: - Navigation Destination Conversion

extension NavigationDestination {
    /// Converts a NavigationDestination to its actual navigation object
    func toNavigationObject(context: NSManagedObjectContext) -> AnyHashable? {
        // Validate Core Data context is ready
        guard context.persistentStoreCoordinator != nil else {
            print("❌ Core Data context not ready for navigation object conversion")
            return nil
        }
        
        switch self {
        case .thread(let threadID, let page, let authorID, let scrollFraction):
            guard let thread = fetchThread(threadID: threadID, context: context) else { 
                print("⚠️ Thread \(threadID) not found during restoration, skipping")
                return nil 
            }
            let author = authorID.flatMap { fetchUser(userID: $0, context: context) }
            return ThreadDestination(thread: thread, page: page, author: author, scrollFraction: scrollFraction)
            
        case .forum(let forumID):
            guard let forum = fetchForum(forumID: forumID, context: context) else {
                print("⚠️ Forum \(forumID) not found during restoration, skipping")
                return nil
            }
            return forum
            
        case .privateMessage(let messageID):
            guard let message = fetchPrivateMessage(messageID: messageID, context: context) else {
                print("⚠️ Message \(messageID) not found during restoration, skipping")
                return nil
            }
            return message
            
        case .composePrivateMessage:
            return ComposePrivateMessage()
            
        case .profile(let userID):
            guard let user = fetchUser(userID: userID, context: context) else {
                print("⚠️ User \(userID) not found during restoration, skipping")
                return nil
            }
            return user
            
        case .rapSheet(let userID):
            guard let user = fetchUser(userID: userID, context: context) else {
                print("⚠️ User \(userID) not found during restoration, skipping")
                return nil
            }
            return user
        }
    }
    
    /// Creates a NavigationDestination from a navigation object
    static func from(_ object: AnyHashable) -> NavigationDestination? {
        switch object {
        case let destination as ThreadDestination:
            return .thread(
                threadID: destination.thread.threadID,
                page: destination.page,
                authorID: destination.author?.userID,
                scrollFraction: destination.scrollFraction
            )
            
        case let forum as Forum:
            return .forum(forumID: forum.forumID)
            
        case let message as PrivateMessage:
            return .privateMessage(messageID: message.messageID)
            
        case is ComposePrivateMessage:
            return .composePrivateMessage
            
        default:
            return nil
        }
    }
}

// MARK: - Core Data Helper Functions

private func fetchThread(threadID: String, context: NSManagedObjectContext) -> AwfulThread? {
    let request = NSFetchRequest<AwfulThread>(entityName: AwfulThread.entityName)
    request.predicate = NSPredicate(format: "threadID == %@", threadID)
    request.fetchLimit = 1
    
    do {
        return try context.fetch(request).first
    } catch {
        print("❌ Failed to fetch thread \(threadID): \(error)")
        return nil
    }
}

private func fetchForum(forumID: String, context: NSManagedObjectContext) -> Forum? {
    let request = NSFetchRequest<Forum>(entityName: Forum.entityName)
    request.predicate = NSPredicate(format: "forumID == %@", forumID)
    request.fetchLimit = 1
    
    do {
        return try context.fetch(request).first
    } catch {
        print("❌ Failed to fetch forum \(forumID): \(error)")
        return nil
    }
}

private func fetchPrivateMessage(messageID: String, context: NSManagedObjectContext) -> PrivateMessage? {
    let request = NSFetchRequest<PrivateMessage>(entityName: PrivateMessage.entityName)
    request.predicate = NSPredicate(format: "messageID == %@", messageID)
    request.fetchLimit = 1
    
    do {
        return try context.fetch(request).first
    } catch {
        print("❌ Failed to fetch message \(messageID): \(error)")
        return nil
    }
}

private func fetchUser(userID: String, context: NSManagedObjectContext) -> User? {
    let request = NSFetchRequest<User>(entityName: User.entityName)
    request.predicate = NSPredicate(format: "userID == %@", userID)
    request.fetchLimit = 1
    
    do {
        return try context.fetch(request).first
    } catch {
        print("❌ Failed to fetch user \(userID): \(error)")
        return nil
    }
}

// ThreadDestination is already defined in MainView.swift

// ComposePrivateMessage is already defined in MainView.swift

// MARK: - ThreadPage Codable Extension

extension ThreadPage: Codable {
    enum CodingKeys: String, CodingKey {
        case type
        case pageNumber
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "first":
            self = .first
        case "last":
            self = .last
        case "nextUnread":
            self = .nextUnread
        case "specific":
            let pageNumber = try container.decode(Int.self, forKey: .pageNumber)
            self = .specific(pageNumber)
        default:
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unknown ThreadPage type"))
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .first:
            try container.encode("first", forKey: .type)
        case .last:
            try container.encode("last", forKey: .type)
        case .nextUnread:
            try container.encode("nextUnread", forKey: .type)
        case .specific(let pageNumber):
            try container.encode("specific", forKey: .type)
            try container.encode(pageNumber, forKey: .pageNumber)
        }
    }
}
