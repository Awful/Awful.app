import AwfulCore
import AwfulSettings
import Combine
import SwiftUI

@MainActor
class LoginViewModel: ObservableObject {
    @Published var username = ""
    @Published var password = ""
    @Published var isLoggingIn = false
    @Published var errorMessage: String?
    
    @FoilDefaultStorage(Settings.canSendPrivateMessages) private var canSendPrivateMessages
    @FoilDefaultStorageOptional(Settings.userID) private var userID
    @FoilDefaultStorageOptional(Settings.username) private var storedUsername
    
    var canAttemptLogin: Bool {
        !username.isEmpty && !password.isEmpty && !isLoggingIn
    }
    
    func logIn() async -> Bool {
        isLoggingIn = true
        errorMessage = nil
        
        do {
            let user = try await ForumsClient.shared.logIn(
                username: username,
                password: password
            )
            canSendPrivateMessages = user.canReceivePrivateMessages
            userID = user.userID
            storedUsername = user.username
            isLoggingIn = false
            return true
        } catch {
            if let error = error as? ServerError, case .banned = error {
                errorMessage = "\(error.localizedDescription): \(error.failureReason ?? "")"
            } else {
                errorMessage = "Problem Logging In: Double-check your username and password, then try again."
            }
            isLoggingIn = false
            return false
        }
    }
} 