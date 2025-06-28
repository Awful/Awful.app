import SwiftUI

private let lostPasswordURL = URL(string: "https://forums.somethingawful.com/account.php?action=lostpw")!
private let privacyPolicyURL = URL(string: "https://awfulapp.com/privacy-policy/")!
private let termsOfServiceURL = URL(string: "https://www.somethingawful.com/forum-rules/forum-rules/")!

struct LoginView: View {
    @StateObject private var viewModel = LoginViewModel()
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Awful")
                .font(.largeTitle)
            
            VStack {
                TextField("Username", text: $viewModel.username)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.username)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                
                SecureField("Password", text: $viewModel.password)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.password)
            }
            .padding(.horizontal)
            
            if viewModel.isLoggingIn {
                ProgressView()
            } else {
                Button("Log In") {
                    Task {
                        _ = await viewModel.logIn()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.canAttemptLogin)
            }
            
            VStack {
                Button("Forgot Password?") {
                    UIApplication.shared.open(lostPasswordURL)
                }
                
                Text(consentToTerms)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .environment(\.openURL, OpenURLAction { url in
                        UIApplication.shared.open(url)
                        return .handled
                    })
            }
            .padding(.horizontal)
        }
        .alert(isPresented: .constant(viewModel.errorMessage != nil), error: LoginError(message: viewModel.errorMessage ?? "")) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        }
    }
    
    private var consentToTerms: AttributedString {
        var string = AttributedString("By logging in, you agree to the Something Awful Privacy Policy and Terms of Service.")
        if let range = string.range(of: "Privacy Policy") {
            string[range].link = privacyPolicyURL
        }
        if let range = string.range(of: "Terms of Service") {
            string[range].link = termsOfServiceURL
        }
        return string
    }
}

private struct LoginError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
} 