import AwfulCore
import AwfulTheming
import SwiftUI

@main
struct AwfulApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var sessionManager = SessionManager()

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(sessionManager)
                .themed()
        }
    }
} 