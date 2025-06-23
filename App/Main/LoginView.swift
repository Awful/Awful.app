import AwfulCore
import AwfulSettings
import AwfulTheming
import SwiftUI

struct LoginView: View {
    @State private var username = ""
    @State private var password = ""
    @State private var loginState: LoginState = .awaitingInput
    @State private var showingError = false
    @State private var errorTitle = ""
    @State private var errorMessage = ""
    @SwiftUI.Environment(\.theme) private var theme
    @SwiftUI.Environment(\.openURL) private var openURL
    @FocusState private var focusedField: Field?
    
    // Note: Settings will be updated directly via Settings class to avoid mutation issues
    
    private enum Field {
        case username, password
    }
    
    private enum LoginState {
        case awaitingInput
        case attemptingLogin
    }
    
    private var canLogin: Bool {
        !username.isEmpty && !password.isEmpty && loginState != .attemptingLogin
    }
    
    private var lostPasswordURL: URL {
        URL(string: "https://forums.somethingawful.com/account.php?action=lostpw")!
    }
    
    private var privacyPolicyURL: URL {
        URL(string: "https://awfulapp.com/privacy-policy/")!
    }
    
    private var termsOfServiceURL: URL {
        URL(string: "https://www.somethingawful.com/forum-rules/forum-rules/")!
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    Spacer(minLength: 40)
                    
                    // App title or logo area
                    VStack(spacing: 8) {
                        Text("Awful")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(theme[color: "tintColor"] ?? .blue)
                        
                        Text("Something Awful Forums")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.bottom, 20)
                    
                    // Login form
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Username")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            TextField("Enter your username", text: $username)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .focused($focusedField, equals: .username)
                                .disabled(loginState == .attemptingLogin)
                                .onChange(of: username) { _ in
                                    updateFocusIfNeeded()
                                }
                                .onSubmit {
                                    handleReturn()
                                }
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Password")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            SecureField("Enter your password", text: $password)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .focused($focusedField, equals: .password)
                                .disabled(loginState == .attemptingLogin)
                                .onChange(of: password) { _ in
                                    updateFocusIfNeeded()
                                }
                                .onSubmit {
                                    handleReturn()
                                }
                        }
                        
                        Button(action: {
                            openURL(lostPasswordURL)
                        }) {
                            Text("Forgot Password?")
                                .font(.footnote)
                                .foregroundColor(theme[color: "tintColor"] ?? .blue)
                        }
                        .opacity(loginState == .attemptingLogin ? 0 : 1)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .padding(.horizontal, 20)
                    
                    // Login button
                    Button(action: attemptLogin) {
                        HStack {
                            if loginState == .attemptingLogin {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                                Text("Logging In...")
                            } else {
                                Text("Log In")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canLogin ? (theme[color: "tintColor"] ?? .blue) : .gray)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(!canLogin)
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    
                    Spacer()
                    
                    // Terms and privacy policy
                    VStack(spacing: 8) {
                        Text("By logging in, you agree to the ")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        +
                        Text("Privacy Policy")
                            .font(.footnote)
                            .foregroundColor(theme[color: "tintColor"] ?? .blue)
                            .underline()
                        +
                        Text(" and ")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        +
                        Text("Terms of Service")
                            .font(.footnote)
                            .foregroundColor(theme[color: "tintColor"] ?? .blue)
                            .underline()
                        +
                        Text(".")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 20)
                    .onTapGesture { coordinate in
                        // Simple link detection - in a real app you might want more sophisticated handling
                        if coordinate.x < 100 { // rough estimate for "Privacy Policy" position
                            openURL(privacyPolicyURL)
                        } else {
                            openURL(termsOfServiceURL)
                        }
                    }
                    
                    Spacer(minLength: 20)
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            focusedField = .username
        }
        .alert(errorTitle, isPresented: $showingError) {
            Button("OK") {
                focusedField = .password
            }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func updateFocusIfNeeded() {
        if focusedField == .username && !username.isEmpty && password.isEmpty {
            focusedField = .password
        }
    }
    
    private func handleReturn() {
        if username.isEmpty {
            focusedField = .username
        } else if password.isEmpty {
            focusedField = .password
        } else if canLogin {
            attemptLogin()
        }
    }
    
    private func attemptLogin() {
        guard canLogin else { return }
        
        loginState = .attemptingLogin
        
        Task {
            do {
                let user = try await ForumsClient.shared.logIn(
                    username: username,
                    password: password
                )
                
                await MainActor.run {
                    // Update settings directly using UserDefaults
                    UserDefaults.standard.set(user.canReceivePrivateMessages, forKey: Settings.canSendPrivateMessages.key)
                    UserDefaults.standard.set(user.userID, forKey: Settings.userID.key)
                    UserDefaults.standard.set(user.username, forKey: Settings.username.key)
                    
                    // Signal successful login
                    NotificationCenter.default.post(name: .didLogIn, object: nil)
                }
            } catch {
                await MainActor.run {
                    loginState = .awaitingInput
                    
                    if let serverError = error as? ServerError, case .banned = serverError {
                        errorTitle = serverError.localizedDescription
                        errorMessage = serverError.failureReason ?? ""
                    } else {
                        errorTitle = "Problem Logging In"
                        errorMessage = "Double-check your username and password, then try again."
                    }
                    
                    showingError = true
                }
            }
        }
    }
}

extension NSNotification.Name {
    static let didLogIn = NSNotification.Name("AwfulDidLogIn")
} 
