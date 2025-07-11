//  NavigationStateRestorationTests.swift
//
//  Copyright 2025 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@testable import Awful
import XCTest
import AwfulCore
import CoreData

final class NavigationStateRestorationTests: XCTestCase {
    
    var stateManager: NavigationStateManager!
    var mockContext: NSManagedObjectContext!
    
    override func setUp() {
        super.setUp()
        mockContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        stateManager = NavigationStateManager(managedObjectContext: mockContext)
    }
    
    override func tearDown() {
        stateManager.clearNavigationState()
        stateManager = nil
        mockContext = nil
        super.tearDown()
    }
    
    // MARK: - Navigation State Tests
    
    func testNavigationStateSaveAndRestore() {
        // Create test navigation state
        let navigationState = NavigationState(
            selectedTab: "forums",
            isTabBarHidden: false,
            mainNavigationPath: [],
            sidebarNavigationPath: [],
            presentedSheet: nil,
            navigationHistory: [],
            unpopStack: [],
            editStates: EditStates(
                isEditingBookmarks: false,
                isEditingMessages: false,
                isEditingForums: false
            ),
            interfaceVersion: NavigationState.currentInterfaceVersion
        )
        
        // Save state
        stateManager.saveNavigationState(navigationState)
        
        // Restore state
        let restoredState = stateManager.restoreNavigationState()
        
        XCTAssertNotNil(restoredState)
        XCTAssertEqual(restoredState?.selectedTab, "forums")
        XCTAssertEqual(restoredState?.isTabBarHidden, false)
        XCTAssertEqual(restoredState?.interfaceVersion, NavigationState.currentInterfaceVersion)
    }
    
    func testNavigationStateWithSheet() {
        let navigationState = NavigationState(
            selectedTab: "forums",
            isTabBarHidden: false,
            mainNavigationPath: [],
            sidebarNavigationPath: [],
            presentedSheet: .search,
            navigationHistory: [],
            unpopStack: [],
            editStates: EditStates(
                isEditingBookmarks: false,
                isEditingMessages: false,
                isEditingForums: false
            ),
            interfaceVersion: NavigationState.currentInterfaceVersion
        )
        
        stateManager.saveNavigationState(navigationState)
        let restoredState = stateManager.restoreNavigationState()
        
        XCTAssertNotNil(restoredState)
        XCTAssertEqual(restoredState?.presentedSheet, .search)
    }
    
    func testNavigationStateWithEditStates() {
        let navigationState = NavigationState(
            selectedTab: "bookmarks",
            isTabBarHidden: true,
            mainNavigationPath: [],
            sidebarNavigationPath: [],
            presentedSheet: nil,
            navigationHistory: [],
            unpopStack: [],
            editStates: EditStates(
                isEditingBookmarks: true,
                isEditingMessages: false,
                isEditingForums: true
            ),
            interfaceVersion: NavigationState.currentInterfaceVersion
        )
        
        stateManager.saveNavigationState(navigationState)
        let restoredState = stateManager.restoreNavigationState()
        
        XCTAssertNotNil(restoredState)
        XCTAssertEqual(restoredState?.selectedTab, "bookmarks")
        XCTAssertEqual(restoredState?.isTabBarHidden, true)
        XCTAssertEqual(restoredState?.editStates.isEditingBookmarks, true)
        XCTAssertEqual(restoredState?.editStates.isEditingMessages, false)
        XCTAssertEqual(restoredState?.editStates.isEditingForums, true)
    }
    
    // MARK: - Navigation Destination Tests
    
    func testNavigationDestinationSerialization() {
        let threadDestination = NavigationDestination.thread(
            threadID: "12345",
            page: .specific(3),
            authorID: "67890",
            scrollFraction: 0.5
        )
        
        let forumDestination = NavigationDestination.forum(forumID: "forum123")
        let messageDestination = NavigationDestination.privateMessage(messageID: "msg456")
        let composeDestination = NavigationDestination.composePrivateMessage
        
        let navigationState = NavigationState(
            selectedTab: "forums",
            isTabBarHidden: false,
            mainNavigationPath: [threadDestination, forumDestination],
            sidebarNavigationPath: [messageDestination],
            presentedSheet: nil,
            navigationHistory: [threadDestination, composeDestination],
            unpopStack: [forumDestination],
            editStates: EditStates(
                isEditingBookmarks: false,
                isEditingMessages: false,
                isEditingForums: false
            ),
            interfaceVersion: NavigationState.currentInterfaceVersion
        )
        
        stateManager.saveNavigationState(navigationState)
        let restoredState = stateManager.restoreNavigationState()
        
        XCTAssertNotNil(restoredState)
        XCTAssertEqual(restoredState?.mainNavigationPath.count, 2)
        XCTAssertEqual(restoredState?.sidebarNavigationPath.count, 1)
        XCTAssertEqual(restoredState?.navigationHistory.count, 2)
        XCTAssertEqual(restoredState?.unpopStack.count, 1)
        
        // Check specific destination types
        if case .thread(let threadID, let page, let authorID, let scrollFraction) = restoredState?.mainNavigationPath[0] {
            XCTAssertEqual(threadID, "12345")
            XCTAssertEqual(page, .specific(3))
            XCTAssertEqual(authorID, "67890")
            XCTAssertEqual(scrollFraction, 0.5)
        } else {
            XCTFail("Expected thread destination")
        }
        
        if case .forum(let forumID) = restoredState?.mainNavigationPath[1] {
            XCTAssertEqual(forumID, "forum123")
        } else {
            XCTFail("Expected forum destination")
        }
    }
    
    // MARK: - ThreadPage Tests
    
    func testThreadPageSerialization() {
        let firstPage = ThreadPage.first
        let lastPage = ThreadPage.last
        let unreadPage = ThreadPage.nextUnread
        let specificPage = ThreadPage.specific(5)
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        // Test first page
        let firstData = try! encoder.encode(firstPage)
        let decodedFirst = try! decoder.decode(ThreadPage.self, from: firstData)
        XCTAssertEqual(decodedFirst, firstPage)
        
        // Test last page
        let lastData = try! encoder.encode(lastPage)
        let decodedLast = try! decoder.decode(ThreadPage.self, from: lastData)
        XCTAssertEqual(decodedLast, lastPage)
        
        // Test unread page
        let unreadData = try! encoder.encode(unreadPage)
        let decodedUnread = try! decoder.decode(ThreadPage.self, from: unreadData)
        XCTAssertEqual(decodedUnread, unreadPage)
        
        // Test specific page
        let specificData = try! encoder.encode(specificPage)
        let decodedSpecific = try! decoder.decode(ThreadPage.self, from: specificData)
        XCTAssertEqual(decodedSpecific, specificPage)
    }
    
    // MARK: - Version Compatibility Tests
    
    func testVersionCompatibility() {
        // Create state with current version
        let navigationState = NavigationState(
            selectedTab: "forums",
            isTabBarHidden: false,
            mainNavigationPath: [],
            sidebarNavigationPath: [],
            presentedSheet: nil,
            navigationHistory: [],
            unpopStack: [],
            editStates: EditStates(
                isEditingBookmarks: false,
                isEditingMessages: false,
                isEditingForums: false
            ),
            interfaceVersion: NavigationState.currentInterfaceVersion
        )
        
        stateManager.saveNavigationState(navigationState)
        let restoredState = stateManager.restoreNavigationState()
        XCTAssertNotNil(restoredState)
        
        // Simulate incompatible version by creating state with different version
        let incompatibleState = NavigationState(
            selectedTab: "forums",
            isTabBarHidden: false,
            mainNavigationPath: [],
            sidebarNavigationPath: [],
            presentedSheet: nil,
            navigationHistory: [],
            unpopStack: [],
            editStates: EditStates(
                isEditingBookmarks: false,
                isEditingMessages: false,
                isEditingForums: false
            ),
            interfaceVersion: 999 // Invalid version
        )
        
        stateManager.saveNavigationState(incompatibleState)
        let restoredIncompatible = stateManager.restoreNavigationState()
        XCTAssertNil(restoredIncompatible) // Should be nil due to version mismatch
    }
    
    // MARK: - Error Handling Tests
    
    func testNoSavedState() {
        stateManager.clearNavigationState()
        let restoredState = stateManager.restoreNavigationState()
        XCTAssertNil(restoredState)
    }
    
    func testClearState() {
        let navigationState = NavigationState(
            selectedTab: "forums",
            isTabBarHidden: false,
            mainNavigationPath: [],
            sidebarNavigationPath: [],
            presentedSheet: nil,
            navigationHistory: [],
            unpopStack: [],
            editStates: EditStates(
                isEditingBookmarks: false,
                isEditingMessages: false,
                isEditingForums: false
            ),
            interfaceVersion: NavigationState.currentInterfaceVersion
        )
        
        stateManager.saveNavigationState(navigationState)
        XCTAssertNotNil(stateManager.restoreNavigationState())
        
        stateManager.clearNavigationState()
        XCTAssertNil(stateManager.restoreNavigationState())
    }
}

// MARK: - Test Helper Extensions

extension ThreadPage: Equatable {
    public static func == (lhs: ThreadPage, rhs: ThreadPage) -> Bool {
        switch (lhs, rhs) {
        case (.last, .last), (.nextUnread, .nextUnread):
            return true
        case (.specific(let lhsPage), .specific(let rhsPage)):
            return lhsPage == rhsPage
        default:
            return false
        }
    }
}

extension PresentedSheetState: Equatable {
    public static func == (lhs: PresentedSheetState, rhs: PresentedSheetState) -> Bool {
        switch (lhs, rhs) {
        case (.search, .search):
            return true
        case (.compose(let lhsTab), .compose(let rhsTab)):
            return lhsTab == rhsTab
        default:
            return false
        }
    }
}

extension NavigationDestination: Equatable {
    public static func == (lhs: NavigationDestination, rhs: NavigationDestination) -> Bool {
        switch (lhs, rhs) {
        case (.thread(let lhsThreadID, let lhsPage, let lhsAuthorID, let lhsScrollFraction), .thread(let rhsThreadID, let rhsPage, let rhsAuthorID, let rhsScrollFraction)):
            return lhsThreadID == rhsThreadID && lhsPage == rhsPage && lhsAuthorID == rhsAuthorID && lhsScrollFraction == rhsScrollFraction
        case (.forum(let lhsForumID), .forum(let rhsForumID)):
            return lhsForumID == rhsForumID
        case (.privateMessage(let lhsMessageID), .privateMessage(let rhsMessageID)):
            return lhsMessageID == rhsMessageID
        case (.composePrivateMessage, .composePrivateMessage):
            return true
        case (.profile(let lhsUserID), .profile(let rhsUserID)):
            return lhsUserID == rhsUserID
        case (.rapSheet(let lhsUserID), .rapSheet(let rhsUserID)):
            return lhsUserID == rhsUserID
        default:
            return false
        }
    }
}