import AwfulCore
import AwfulTheming
import SwiftUI

struct RootView: View {
    @StateObject private var viewModel = AppViewModel()
    
    var body: some View {
        Group {
            if viewModel.isLoggedIn {
                MainView()
            } else {
                LoginView()
            }
        }
        .themed()
    }
} 