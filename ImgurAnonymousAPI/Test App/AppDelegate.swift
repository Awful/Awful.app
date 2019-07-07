// Public domain. https://github.com/nolanw/ImgurAnonymousAPI

import ImgurAnonymousAPI
import UIKit

@UIApplicationMain
final class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        ImgurUploader.logger = { level, message in
            print("\(level): \(message())")
        }

        return true
    }
}
