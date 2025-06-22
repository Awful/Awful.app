import AwfulCore
import SwiftUI
import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        self.window = window

        if ForumsClient.shared.isLoggedIn {
            window.rootViewController = UIHostingController(rootView: MainView())
        } else {
            let login = LoginViewController.newFromStoryboard()
            login.completionBlock = { [weak self] _ in
                self?.window?.rootViewController = UIHostingController(rootView: MainView())
            }
            window.rootViewController = login
        }
        
        window.makeKeyAndVisible()
    }
} 