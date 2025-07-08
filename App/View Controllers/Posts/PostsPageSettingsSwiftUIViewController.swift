import SwiftUI
import UIKit
import AwfulTheming

/// A hosting controller that presents the SwiftUI PostsPageSettingsView
final class PostsPageSettingsSwiftUIViewController: UIHostingController<AnyView> {
    
    init() {
        super.init(rootView: AnyView(PostsPageSettingsView().themed()))
        
        // Configure presentation style based on device type
        if UIDevice.current.userInterfaceIdiom == .pad {
            modalPresentationStyle = .popover
            popoverPresentationController?.delegate = self
        } else {
            // For iPhone, use a sheet presentation
            modalPresentationStyle = .pageSheet
            if let sheet = sheetPresentationController {
                sheet.detents = [.medium()]
                sheet.prefersGrabberVisible = true
            }
        }
    }
    
    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - UIPopoverPresentationControllerDelegate
extension PostsPageSettingsSwiftUIViewController: UIPopoverPresentationControllerDelegate {
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .none
    }
} 
