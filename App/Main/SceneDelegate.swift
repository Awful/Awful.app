import AwfulCore
import AwfulSettings
import AwfulTheming
import Combine
import SwiftUI
import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        self.window = window

        let awfulApp = MainView().themed()

        if ForumsClient.shared.isLoggedIn {
            let hostingController = UIHostingController(rootView: awfulApp)
            hostingController.view.backgroundColor = .clear
            
            let navigationController = NavigationController(rootViewController: hostingController)
            navigationController.isNavigationBarHidden = true
            
            window.rootViewController = navigationController
        } else {
            let login = LoginViewController.newFromStoryboard()
        login.completionBlock = { [weak self] _ in
                let hostingController = UIHostingController(rootView: awfulApp)
                hostingController.view.backgroundColor = .clear
                
                let navigationController = NavigationController(rootViewController: hostingController)
                navigationController.isNavigationBarHidden = true
                
                self?.window?.rootViewController = navigationController
            }
            window.rootViewController = login
        }
        
        window.makeKeyAndVisible()
    }
} 
