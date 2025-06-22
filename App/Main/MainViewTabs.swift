import AwfulCore
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
    var view: some View {
        let managedObjectContext = AppDelegate.instance.managedObjectContext
        
        switch self {
        case .forums:
            let vc = ForumsTableViewController(managedObjectContext: managedObjectContext)
            AwfulUIViewControllerRepresentable { vc.enclosingNavigationController }
        case .bookmarks:
            let vc = BookmarksTableViewController(managedObjectContext: managedObjectContext)
            AwfulUIViewControllerRepresentable { vc.enclosingNavigationController }
        case .messages:
            let vc = MessageListViewController(managedObjectContext: managedObjectContext)
            AwfulUIViewControllerRepresentable { vc.enclosingNavigationController }
        case .lepers:
            let vc = RapSheetViewController()
            AwfulUIViewControllerRepresentable { vc.enclosingNavigationController }
        case .settings:
            let vc = SettingsViewController(managedObjectContext: managedObjectContext)
            AwfulUIViewControllerRepresentable { vc.enclosingNavigationController }
        }
    }
} 