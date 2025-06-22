import AwfulCore
import CoreData
import SwiftUI
import UIKit

struct AwfulUIViewControllerRepresentable: UIViewControllerRepresentable {
    let makeViewController: () -> UIViewController

    init(_ makeViewController: @escaping () -> UIViewController) {
        self.makeViewController = makeViewController
    }

    func makeUIViewController(context: Context) -> UIViewController {
        return makeViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

struct BookmarksViewRepresentable: UIViewControllerRepresentable {
    @Binding var isEditing: Bool
    let managedObjectContext: NSManagedObjectContext
    
    func makeUIViewController(context: Context) -> UIViewController {
        let bookmarksVC = BookmarksTableViewController(managedObjectContext: managedObjectContext)
        return bookmarksVC.enclosingNavigationController(hidingNavigationBar: true)
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        if let navController = uiViewController as? UINavigationController,
           let bookmarksVC = navController.viewControllers.first as? BookmarksTableViewController {
            bookmarksVC.setEditing(isEditing, animated: true)
        }
    }
}

struct MessagesViewRepresentable: UIViewControllerRepresentable {
    @Binding var isEditing: Bool
    let managedObjectContext: NSManagedObjectContext
    
    func makeUIViewController(context: Context) -> UIViewController {
        let messagesVC = MessageListViewController(managedObjectContext: managedObjectContext)
        let nav = messagesVC.enclosingNavigationController(hidingNavigationBar: true)
        return nav
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        if let navController = uiViewController as? UINavigationController,
           let messagesVC = navController.viewControllers.first as? MessageListViewController {
            messagesVC.setEditing(isEditing, animated: true)
        }
    }
}

struct ForumsViewRepresentable: UIViewControllerRepresentable {
    @Binding var isEditing: Bool
    @Binding var hasFavorites: Bool
    let managedObjectContext: NSManagedObjectContext
    
    func makeUIViewController(context: Context) -> UIViewController {
        let forumsVC = ForumsTableViewController(managedObjectContext: managedObjectContext)
        let nav = forumsVC.enclosingNavigationController(hidingNavigationBar: true)
        
        // Set up favorite forums count observation
        let coordinator = context.coordinator
        coordinator.setupFavoriteForumsObserver(managedObjectContext: managedObjectContext) { count in
            DispatchQueue.main.async {
                hasFavorites = count > 0
            }
        }
        
        return nav
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        if let navController = uiViewController as? UINavigationController,
           let forumsVC = navController.viewControllers.first as? ForumsTableViewController {
            forumsVC.setEditing(isEditing, animated: true)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject {
        private var favoriteForumCountObserver: NSObjectProtocol?
        
        func setupFavoriteForumsObserver(managedObjectContext: NSManagedObjectContext, countChanged: @escaping (Int) -> Void) {
            let request = NSFetchRequest<NSManagedObject>(entityName: "ForumMetadata")
            request.predicate = NSPredicate(format: "favorite == YES")
            
            favoriteForumCountObserver = NotificationCenter.default.addObserver(
                forName: .NSManagedObjectContextDidSave,
                object: managedObjectContext,
                queue: .main
            ) { _ in
                do {
                    let count = try managedObjectContext.count(for: request)
                    countChanged(count)
                } catch {
                    print("Error counting favorite forums: \(error)")
                }
            }
            
            // Get initial count
            do {
                let count = try managedObjectContext.count(for: request)
                countChanged(count)
            } catch {
                print("Error getting initial favorite forums count: \(error)")
            }
        }
        
        deinit {
            if let observer = favoriteForumCountObserver {
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }
}

enum Tab: CaseIterable, Identifiable {
    case forums
    case bookmarks
    case messages
    case lepers
    case settings
    
    var id: Self { self }
    
    var image: String {
        switch self {
        case .forums: return "forum-list"
        case .bookmarks: return "bookmarks"
        case .messages: return "pm-icon"
        case .lepers: return "lepers"
        case .settings: return "cog"
        }
    }
    
    var selectedImage: String {
        switch self {
        case .forums: return "forum-list-filled"
        case .bookmarks: return "bookmarks-filled"
        case .messages: return "pm-icon-filled"
        case .lepers: return "lepers-filled"
        case .settings: return "cog-filled"
        }
    }
    
    var title: String {
        switch self {
        case .forums: return "Forums"
        case .bookmarks: return "Bookmarks"
        case .messages: return "Messages"
        case .lepers: return "Lepers"
        case .settings: return "Settings"
        }
    }
    
    @ViewBuilder
    func view(
        isPad: Bool,
        bookmarksIsEditing: Binding<Bool>? = nil,
        messagesIsEditing: Binding<Bool>? = nil,
        forumsIsEditing: Binding<Bool>? = nil,
        forumsHasFavorites: Binding<Bool>? = nil
    ) -> some View {
        let managedObjectContext = AppDelegate.instance.managedObjectContext
        
        switch self {
        case .forums:
            if let forumsIsEditing = forumsIsEditing, let forumsHasFavorites = forumsHasFavorites {
                ForumsViewRepresentable(
                    isEditing: forumsIsEditing,
                    hasFavorites: forumsHasFavorites,
                    managedObjectContext: managedObjectContext
                )
            } else {
                let vc = ForumsTableViewController(managedObjectContext: managedObjectContext)
                AwfulUIViewControllerRepresentable { vc.enclosingNavigationController(hidingNavigationBar: true) }
            }
        case .bookmarks:
            if let bookmarksIsEditing = bookmarksIsEditing {
                BookmarksViewRepresentable(isEditing: bookmarksIsEditing, managedObjectContext: managedObjectContext)
            } else {
                let vc = BookmarksTableViewController(managedObjectContext: managedObjectContext)
                AwfulUIViewControllerRepresentable { vc.enclosingNavigationController(hidingNavigationBar: true) }
            }
        case .messages:
            if let messagesIsEditing = messagesIsEditing {
                MessagesViewRepresentable(isEditing: messagesIsEditing, managedObjectContext: managedObjectContext)
            } else {
                let vc = MessageListViewController(managedObjectContext: managedObjectContext)
                AwfulUIViewControllerRepresentable { vc.enclosingNavigationController(hidingNavigationBar: true) }
            }
        case .lepers:
            let vc = RapSheetViewController()
            AwfulUIViewControllerRepresentable { vc.enclosingNavigationController(hidingNavigationBar: true) }
        case .settings:
            AwfulUIViewControllerRepresentable { SettingsViewController(managedObjectContext: managedObjectContext) }
        }
    }
} 
