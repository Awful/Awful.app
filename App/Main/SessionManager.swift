import AwfulCore
import Combine
import SwiftUI

final class SessionManager: ObservableObject {
    @Published private(set) var isLoggedIn: Bool

    private var cancellables: Set<AnyCancellable> = []

    init() {
        self.isLoggedIn = ForumsClient.shared.isLoggedIn
        
        NotificationCenter.default.publisher(for: .didLogIn)
            .sink { [weak self] _ in self?.updateLoginState() }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .didRemotelyLogOut)
            .sink { [weak self] _ in self?.updateLoginState() }
            .store(in: &cancellables)
    }

    private func updateLoginState() {
        isLoggedIn = ForumsClient.shared.isLoggedIn
    }
} 