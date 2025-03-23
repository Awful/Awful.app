//  ImgurAnonymousAPI+Shared.swift
//
//  Copyright 2025 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation
import ImgurAnonymousAPI
import UIKit
import os
import AwfulSettings
import KeychainAccess
import AuthenticationServices

// App-specific Imgur constants
private enum AppImgurConstants {
    static let clientID = "99240c4154dd0b4"
}

// MARK: - Imgur Auth Manager

private let authLogger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "ImgurAuthManager")

/// Manager for handling Imgur authentication and token storage
public final class ImgurAuthManager: NSObject, ImgurAuthProvider {
    public static let shared = ImgurAuthManager()
    
    private let defaults = UserDefaults.standard
    private var authSession: ASWebAuthenticationSession?
    private var presentationContextProvider: PresentationContextProvider?
    
    private let keychain = Keychain(service: "com.awfulapp.Awful.imgur")
    
    private enum KeychainKeys {
        static let bearerToken = "imgur_bearer_token"
        static let refreshToken = "imgur_refresh_token"
        static let tokenExpiry = "imgur_token_expiry"
    }
    
    public enum DefaultsKeys {
        static let rateLimited = "imgur_rate_limited"
    }
    
    @FoilDefaultStorage(Settings.imgurUploadMode) private var imgurUploadMode
    
    private override init() {
        super.init()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleClearCredentialsNotification),
            name: Notification.Name("ClearImgurCredentials"),
            object: nil
        )
    }
    
    @objc private func handleClearCredentialsNotification() {
        authLogger.info("Clearing Imgur credentials due to upload mode change")
        logout()
    }
    
    // MARK: - ImgurAuthProvider Protocol
    
    public var clientID: String {
        return AppImgurConstants.clientID
    }
    
    public var isAuthenticated: Bool {
        return keychain[KeychainKeys.bearerToken] != nil
    }
    
    public var currentUploadMode: String {
        return imgurUploadMode.rawValue
    }
    
    public var needsAuthentication: Bool {
        return imgurUploadMode == .account && !isAuthenticated
    }
    
    public var bearerToken: String? {
        return keychain[KeychainKeys.bearerToken]
    }
    
    /// Check if the token is expired and needs a refresh
    public func checkTokenExpiry() -> Bool {
        guard let expiryString = keychain[KeychainKeys.tokenExpiry],
              let expiryTime = Double(expiryString) else {
            return true // If no expiry time, assume expired
        }
        
        // Check if the token is expired (with a 5-minute buffer)
        let currentTime = Date().timeIntervalSince1970
        return currentTime > (expiryTime - 300) // 5-minute buffer
    }
    
    public func logout() {
        do {
            try keychain.remove(KeychainKeys.bearerToken)
            try keychain.remove(KeychainKeys.refreshToken)
            try keychain.remove(KeychainKeys.tokenExpiry)
            authLogger.info("Cleared all Imgur authentication tokens from keychain")
        } catch {
            authLogger.error("Error clearing tokens from keychain: \(error.localizedDescription)")
        }
    }
    
    /// Start the authentication process
    public func authenticate(from viewController: UIViewController, completion: @escaping (Bool) -> Void) {
        guard let authURL = URL(string: "https://api.imgur.com/oauth2/authorize?client_id=\(clientID)&response_type=token&state=awful") else {
            authLogger.error("Could not create Imgur OAuth URL")
            completion(false)
            return
        }
        
        authLogger.debug("Starting authentication with URL: \(authURL.absoluteString)")
        
        let callbackURLScheme = "awful"
        
        guard let presentationAnchor = viewController.view.window else {
            authLogger.error("Could not get presentation anchor for authentication")
            completion(false)
            return
        }
        
        self.presentationContextProvider = PresentationContextProvider(anchor: presentationAnchor)
        
        authSession = ASWebAuthenticationSession(
            url: authURL,
            callbackURLScheme: callbackURLScheme
        ) { [weak self] callbackURL, error in
            guard let self = self else { return }
            
            if let error = error {
                let errorString = error.localizedDescription
                
                if errorString.contains("cancelled") {
                    authLogger.info("User cancelled Imgur authentication")
                } else {
                    authLogger.error("Imgur authentication failed: \(errorString)")
                }
                
                completion(false)
                return
            }
            
            guard let callbackURL = callbackURL else {
                authLogger.error("No callback URL received from Imgur")
                completion(false)
                return
            }
            
            authLogger.debug("Received callback URL: \(callbackURL.absoluteString)")
            
            if let authError = ImgurOAuthResponse.checkForError(in: callbackURL) {
                if case .rateLimited = authError {
                    authLogger.error("Imgur rate limit exceeded")
                    self.defaults.set(true, forKey: DefaultsKeys.rateLimited)
                    // Set a timer to clear the rate limit flag after 1 hour
                    DispatchQueue.global().asyncAfter(deadline: .now() + 3600) {
                        self.defaults.set(false, forKey: DefaultsKeys.rateLimited)
                    }
                } else {
                    authLogger.error("Imgur authentication error: \(authError)")
                    self.defaults.set(false, forKey: DefaultsKeys.rateLimited)
                }
                
                completion(false)
                return
            }
            
            if let fragment = callbackURL.fragment, 
               let response = ImgurOAuthResponse.parse(from: fragment) {
                
                self.keychain[KeychainKeys.bearerToken] = response.accessToken
                self.keychain[KeychainKeys.refreshToken] = response.refreshToken
                
                let expiryTime = Date().timeIntervalSince1970 + response.expiresIn
                self.keychain[KeychainKeys.tokenExpiry] = String(expiryTime)
                
                authLogger.info("Successfully authenticated with Imgur")
                completion(true)
            } else {
                authLogger.error("Could not extract token information from callback URL")
                completion(false)
            }
        }
        
        authSession?.presentationContextProvider = self.presentationContextProvider
        authSession?.prefersEphemeralWebBrowserSession = true
        
        if !(authSession?.start() ?? false) {
            authLogger.error("Failed to start Imgur authentication session")
            completion(false)
        }
    }
}

private class PresentationContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    private let anchor: ASPresentationAnchor
    
    init(anchor: ASPresentationAnchor) {
        self.anchor = anchor
        super.init()
    }
    
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return anchor
    }
}

// MARK: - Imgur Uploader Configuration

private let uploaderLogger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "ImgurUploaderConfig")

extension ImgurUploader {
    static var shared: ImgurUploader {
        let imgurUploadMode = ImgurAuthManager.shared.currentUploadMode
        
        if imgurUploadMode == "Imgur Account", ImgurAuthManager.shared.isAuthenticated {
            uploaderLogger.debug("Using authenticated Imgur uploader with bearer token")
            return authenticatedUploader
        }
        
        uploaderLogger.debug("Using anonymous Imgur uploader")
        return anonymousUploader
    }
    
    private static var authenticatedUploader: ImgurUploader = {
        let uploader = ImgurUploader(authProvider: ImgurAuthManager.shared)
        configureLogger(for: uploader)
        return uploader
    }()
}

private let anonymousUploader: ImgurUploader = {
    let uploader = ImgurUploader(authProvider: ImgurAuthManager.shared)
    configureLogger(for: uploader)
    return uploader
}()

private func configureLogger(for uploader: ImgurUploader) {
    ImgurUploader.logger = { level, messageProvider in
        let message = messageProvider()
        switch level {
        case .debug:
            uploaderLogger.debug("\(message)")
        case .info:
            uploaderLogger.info("\(message)")
        case .error:
            uploaderLogger.error("\(message)")
        }
    }
}
