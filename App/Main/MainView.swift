import SwiftUI

struct MainView: View {
    @State private var selectedTab: Tab = .forums
    
    var body: some View {
        GeometryReader { proxy in
            let isCompact = proxy.size.width < 768 // rough heuristic for iPhone vs iPad/Mac
            if isCompact {
                TabView(selection: $selectedTab) {
                    ForEach(Tab.allCases) { tab in
                        tab.view
                            .tabItem {
                                Label(tab.title, systemImage: tab.image)
                            }
                            .tag(tab)
                    }
                }
            } else {
                NavigationSplitView {
                    TabView(selection: $selectedTab) {
                        ForEach(Tab.allCases) { tab in
                            tab.view
                                .tabItem {
                                    Label(tab.title, systemImage: tab.image)
                                }
                                .tag(tab)
                        }
                    }
                } detail: {
                    Text("Select an item")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.systemBackground))
                }
            }
        }
    }
} 