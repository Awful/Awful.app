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
    func toNavigationObject(context: NSManagedObjectContext, viewStateStorage: [String: [String: Any]]? = nil) -> AnyHashable? {
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
            print("🔍 RESTORATION DEBUG: Creating ThreadDestination with saved page: \(page)")
            
            // Check if there's more recent view state that indicates a different page
            // This prevents restoring stale 'nextUnread' when user was actually on a specific page
            let finalPage: ThreadPage
            if let viewStateStorage = viewStateStorage,
               let viewState = viewStateStorage[threadID], 
               let savedPageNumber = viewState["currentPage"] as? Int, 
               savedPageNumber > 0,
               case .nextUnread = page {
                // Override nextUnread with the specific page from view state
                finalPage = .specific(savedPageNumber)
                print("🔍 RESTORATION OVERRIDE: Using specific(\(savedPageNumber)) from view state instead of nextUnread")
            } else {
                finalPage = page
            }
            
            let destination = ThreadDestination(thread: thread, page: finalPage, author: author, scrollFraction: scrollFraction)
            print("🔍 RESTORATION DEBUG: Created ThreadDestination has page: \(destination.page)")
            return destination
            
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
            return PrivateMessageDestination(message: message)
            
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
            
        case let destination as PrivateMessageDestination:
            return .privateMessage(messageID: destination.message.messageID)
            
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

