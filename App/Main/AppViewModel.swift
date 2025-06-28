import AwfulCore
import AwfulSettings
import Combine
import SwiftUI

@MainActor
class AppViewModel: ObservableObject {
    @Published private(set) var isLoggedIn: Bool

    private var cancellables: Set<AnyCancellable> = []
    
    init() {
        // Synchronize the login state between cookies and UserDefaults
        let hasValidCookies = ForumsClient.shared.isLoggedIn
        let hasUserDefaults = UserDefaults.standard.value(for: Settings.userID) != nil
        
        // Debug: Let's see what's happening with the login state
        print("🔍 AppViewModel init:")
        print("  ForumsClient.shared.isLoggedIn: \(hasValidCookies)")
        print("  UserDefaults userID: \(UserDefaults.standard.value(for: Settings.userID) ?? "nil")")
        print("  Login cookie exists: \(ForumsClient.shared.loginCookieExpiryDate != nil)")
        
        // If we have cookies but no UserDefaults, clear the cookies to force a fresh login
        if hasValidCookies && !hasUserDefaults {
            print("🔍 Inconsistent state detected: clearing cookies to force fresh login")
            // Clear all cookies to ensure a clean logout state
            if let cookies = HTTPCookieStorage.shared.cookies {
                for cookie in cookies {
                    HTTPCookieStorage.shared.deleteCookie(cookie)
                }
            }
        }
        
        // Now check the actual state after potential cleanup
        isLoggedIn = ForumsClient.shared.isLoggedIn && hasUserDefaults
        
        NotificationCenter.default.publisher(for: .DidLogIn)
            .sink { [weak self] _ in 
                print("🔍 Received DidLogIn notification")
                self?.isLoggedIn = true 
            }
            .store(in: &cancellables)
            
        NotificationCenter.default.publisher(for: .DidLogOut)
            .sink { [weak self] _ in 
                print("🔍 Received DidLogOut notification")
                self?.isLoggedIn = false 
            }
            .store(in: &cancellables)
    }
} 