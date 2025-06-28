import AwfulCore
import SwiftUI

struct RootView: View {
    @StateObject private var viewModel = AppViewModel()
    
    var body: some View {
        if viewModel.isLoggedIn {
            MainView()
        } else {
            LoginView()
        }
    }
} 