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
        
        // If we have cookies but no UserDefaults, clear the cookies to force a fresh login
        if hasValidCookies && !hasUserDefaults {
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
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in 
                self?.isLoggedIn = true 
            }
            .store(in: &cancellables)
            
        NotificationCenter.default.publisher(for: .DidLogOut)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in 
                self?.isLoggedIn = false 
            }
            .store(in: &cancellables)
    }
} 