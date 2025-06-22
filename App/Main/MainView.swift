import SwiftUI

struct MainView: View {
    @State private var selectedTab: Tab = .forums
    @SwiftUI.Environment(\.theme) private var theme
    @SwiftUI.Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Fill the status-bar area with the navigation bar tint color
            (theme[color: "navigationBarTintColor"] ?? Color.blue)
                .ignoresSafeArea(edges: .top)
            
            GeometryReader { proxy in
                let isCompact = proxy.size.width < 768 // rough heuristic for iPhone vs iPad/Mac
                if isCompact {
                    TabView(selection: $selectedTab) {
                        ForEach(Tab.allCases) { tab in
                            tab.view
                                .tabItem {
                                    Image(tab.image)
                                        .renderingMode(.template)
                                    Text(tab.title)
                                }
                                .tag(tab)
                        }
                    }
                    .tint(theme[color: "tabBarIconSelectedColor"])
                    .preferredColorScheme(theme["mode"] == "dark" ? .dark : .light)
                } else {
                    NavigationSplitView {
                        TabView(selection: $selectedTab) {
                            ForEach(Tab.allCases) { tab in
                                tab.view
                                    .tabItem {
                                        Image(tab.image)
                                            .renderingMode(.template)
                                        Text(tab.title)
                                    }
                                    .tag(tab)
                            }
                        }
                        .tint(theme[color: "tabBarIconSelectedColor"])
                    } detail: {
                        Text("Select an item")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(theme[color: "backgroundColor"] ?? Color(.systemBackground))
                    }
                    .preferredColorScheme(theme["mode"] == "dark" ? .dark : .light)
                }
            }
        }
    }
}

#Preview {
    MainView()
}
