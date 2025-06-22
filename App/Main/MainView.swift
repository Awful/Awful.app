import SwiftUI

struct MainView: View {
    @State private var selectedTab: Tab? = .forums
    @SwiftUI.Environment(\.theme) private var theme
    @SwiftUI.Environment(\.colorScheme) private var colorScheme
    
    private var fontDesign: Font.Design {
        theme[bool: "roundedFonts"] == true ? .rounded : .default
    }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Fill the status-bar area with the navigation bar tint color
            (theme[color: "navigationBarTintColor"] ?? Color.blue)
                .ignoresSafeArea(edges: .top)
            
            GeometryReader { proxy in
                let isCompact = proxy.size.width < 768 // rough heuristic for iPhone vs iPad/Mac
                if isCompact {
                    MainViewContent(selectedTab: $selectedTab)
                        .preferredColorScheme(theme["mode"] == "dark" ? .dark : .light)
                } else {
                    NavigationSplitView {
                        MainViewContent(selectedTab: $selectedTab)
                            .background(theme[color: "backgroundColor"] ?? Color(.systemGroupedBackground))
                    } detail: {
                        Text("")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(theme[color: "backgroundColor"] ?? Color(.systemBackground))
                    }
                    .preferredColorScheme(theme["mode"] == "dark" ? .dark : .light)
                }
            }
            .fontDesign(fontDesign)
        }
    }
}

private struct MainViewContent: View {
    @Binding var selectedTab: Tab?
    @SwiftUI.Environment(\.theme) private var theme
    @SwiftUI.Environment(\.colorScheme) private var colorScheme
    @SwiftUI.Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var isBookmarksEditing = false
    @State private var isMessagesEditing = false
    @State private var isForumsEditing = false
    @State private var forumsHasFavorites = false
    
    private var isPad: Bool {
        horizontalSizeClass == .regular
    }

    private var navigationBarColorScheme: ColorScheme? {
        if theme["statusBarBackground"] == "light" {
            return .light
        } else if theme["statusBarBackground"] == "dark" {
            return .dark
        }
        return nil
    }

    private var showLabels: Bool {
        theme[bool: "showRootTabBarLabel"] != false
    }

    private var selectedColor: Color {
        theme[color: "tabBarIconSelectedColor"] ?? .blue
    }

    private var iconColor: Color {
        theme[color: "tabBarIconColor"] ?? .gray
    }

    private var textColor: Color {
        theme[color: "tabBarTextColor"] ?? .gray
    }

    private var backgroundColor: Color {
        theme[color: "tabBarBackgroundColor"] ?? Color(.systemBackground)
    }



    var body: some View {
        VStack(spacing: 0) {
            if let selectedTab {
                selectedTab.view(
                    isPad: isPad,
                    bookmarksIsEditing: selectedTab == .bookmarks ? $isBookmarksEditing : nil,
                    messagesIsEditing: selectedTab == .messages ? $isMessagesEditing : nil,
                    forumsIsEditing: selectedTab == .forums ? $isForumsEditing : nil,
                    forumsHasFavorites: selectedTab == .forums ? $forumsHasFavorites : nil
                )
            }

            VStack(spacing: 0) {
                Divider()
                    .background(Color.gray.opacity(0.3))

                HStack(spacing: 0) {
                    ForEach(Tab.allCases) { tab in
                        Button(action: { selectedTab = tab }) {
                            VStack(spacing: showLabels ? 4 : 0) {
                                Image(tab.image)
                                    .renderingMode(.template)
                                    .foregroundColor(selectedTab == tab ? selectedColor : iconColor)
                                    .font(.system(size: 20))
                                    .padding(.vertical, showLabels ? 0 : 9)

                                if showLabels {
                                    Text(tab.title)
                                        .font(.caption)
                                        .foregroundColor(selectedTab == tab ? selectedColor : textColor)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, showLabels ? 8 : 0)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .background(backgroundColor)
            }
            .frame(height: 50)
        }
        .background(theme[color: "navigationBarTintColor"])
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(theme[color: "navigationBarTintColor"] ?? .blue, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(navigationBarColorScheme, for: .navigationBar)
        .tint(theme[color: "navigationBarTextColor"])
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(selectedTab?.title ?? "")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(theme[color: "navigationBarTextColor"])
            }
            
            if selectedTab == .forums && forumsHasFavorites {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isForumsEditing ? "Done" : "Edit") {
                        isForumsEditing.toggle()
                    }
                    .foregroundColor(theme[color: "navigationBarTextColor"])
                }
            }
            
            if selectedTab == .bookmarks {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isBookmarksEditing ? "Done" : "Edit") {
                        isBookmarksEditing.toggle()
                    }
                    .foregroundColor(theme[color: "navigationBarTextColor"])
                }
            }
            
            if selectedTab == .messages {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(isMessagesEditing ? "Done" : "Edit") {
                        isMessagesEditing.toggle()
                    }
                    .foregroundColor(theme[color: "navigationBarTextColor"])
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        // We need to present the compose view controller
                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let window = windowScene.windows.first,
                           let rootVC = window.rootViewController {
                            let compose = MessageComposeViewController()
                            compose.restorationIdentifier = "New message"
                            rootVC.present(compose.enclosingNavigationController(), animated: true)
                        }
                    }) {
                        Image(systemName: "square.and.pencil")
                            .foregroundColor(theme[color: "navigationBarTextColor"])
                    }
                }
            }
        }
    }
}

#Preview {
    MainView()
}
