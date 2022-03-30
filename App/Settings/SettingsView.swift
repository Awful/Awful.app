//  SettingsView.swift
//
//  Copyright 2022 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import SwiftUI
import NukeUI
import AwfulCore

private let Log = Logger.get()

@available(iOS 14.0, *)
class SettingsViewModel: Identifiable, ObservableObject {
    @SwiftUI.Environment(\.managedObjectContext) var managedObjectContext
    @AppStorage("show_images") var loadImages = true
    @AppStorage("show_avatars") var showAvatars = true
    @AppStorage("font_scale") var fontScale = 100
    @AppStorage("confirm_before_replying") var confirmBeforeReply = true
    @AppStorage("autoplay_gifs") var autoplayGIFs = true
    @AppStorage("embed_tweets") var embedTweets = true
    @AppStorage("jump_to_post_end_on_double_tap") var doubleTapJump = true
    @AppStorage("enable_haptics") var enableHaptics = true
    @AppStorage("automatic_timg") var autoTIMG = true
    @AppStorage("bookmarks_sorted_unread") var sortUnreadBookmarks = true
    @AppStorage("show_thread_tags") var showThreadTags = true
    @AppStorage("forum_threads_sorted_unread") var sortUnreadThreads = true
    @AppStorage("pull_for_next") var pullForNext = true
    @AppStorage("hide_sidebar_in_landscape") var hideSidebarInLandscape = true
    @AppStorage("open_youtube_links_in_youtube") var openInYoutube = true
    @AppStorage("open_twitter_links_in_twitter") var openInTwitter = true
    @AppStorage("dark_theme") var darkModeEnabled = true
    @AppStorage("auto_dark_theme") var automaticDarkModeEnabled = true
    @AppStorage("handoff_enabled") var handoffEnabled = true
    @AppStorage("clipboard_url_enabled") var clipboardURLEnabled = true
    @AppStorage("show_unread_announcements_badge") var showUnreadAnnouncements = true
    @AppStorage("default_dark_theme_name") var defaultDarkTheme = ""
    @AppStorage("default_light_theme_name") var defaultLightTheme = ""
        
    var expiryDate = DateFormatter.localizedString(from: ForumsClient.shared.loginCookieExpiryDate ?? .distantFuture, dateStyle: .medium, timeStyle: .short)
    
    func getloggedInUser() -> User? {
        guard let userID = UserDefaults.standard.loggedInUserID else { return nil }
        let userKey = UserKey(userID: userID, username: UserDefaults.standard.loggedInUsername)
        return User.objectForKey(objectKey: userKey, in: ForumsClient.shared.managedObjectContext!)
    }
    
    var version: String = {
        let title: String = {
            var components = [Bundle.main.localizedName, Bundle.main.shortVersionString]
            if Environment.isDebugBuild || Environment.isSimulator || Environment.isInstalledViaTestFlight {
                components.append(Bundle.main.version.map { "(\($0))" })
            }
            return components.compactMap { $0 }.joined(separator: " ")
        }()
        return title
    }()
    
}


@available(iOS 14.0, *)
struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @SwiftUI.Environment(\.managedObjectContext) var managedObjectContext
    @SwiftUI.Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            Color(Theme.defaultTheme()[color: "backgroundColor"] ?? .clear).ignoresSafeArea()
            Form {
                Group {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(self.viewModel.getloggedInUser()?.username ?? "Preview Pete")
                            Text(self.viewModel.getloggedInUser()?.regdateRaw ?? "01 Jan 2000")
                            
                            if (self.viewModel.getloggedInUser()?.avatarURLString) != nil {
                                LazyImage(source: self.viewModel.getloggedInUser()?.avatarURLString)
                                    .frame(width: 100, height: 100)
                            } else {
                                Image("title-probation").frame(width: 100, height: 100).padding()
                            }
                            Text("Cookie expires on \(self.viewModel.expiryDate)")
                                .font(.system(.caption, design: .rounded))
                        }
                    }
                    Section {
                        Button("Log Out"){
                            AppDelegate.instance.logOut();
                        }
                        Button("Empty Cache"){
                            AppDelegate.instance.emptyCache();
                        }
                        Button("Go To Thread"){
                            AppDelegate.instance.open(route: .threadPage(threadID: "3837546", page: .nextUnread, .seen))
                        }
                    }
                    SettingsSections(viewModel: self.viewModel)
                }
                .listRowBackground(Color(Theme.defaultTheme()[color: "backgroundColor"] ?? .clear))
                .foregroundColor(colorScheme == .dark ? .white : .black)
                .awfulToggleStyle()
            }
            .onAppear {
                UITableView.appearance().backgroundColor = .clear
                UITableView.appearance().separatorColor = .clear
            }
            .onChange(of: self.viewModel.$darkModeEnabled.wrappedValue) { newValue in
                UITableView.appearance().backgroundColor = .clear
                UITableView.appearance().separatorColor = .clear
            }
            .onChange(of: self.viewModel.$defaultDarkTheme.wrappedValue) { newValue in
                UITableView.appearance().backgroundColor = .clear
                UITableView.appearance().separatorColor = .clear
            }
            .onChange(of: self.viewModel.$defaultLightTheme.wrappedValue) { newValue in
                UITableView.appearance().backgroundColor = .clear
                UITableView.appearance().separatorColor = .clear
            }
        }
        .foregroundColor(colorScheme == .dark ? .white : .black)
    }
}

@available(iOS 14.0, *)
struct SettingsSections: View {
    var viewModel: SettingsViewModel
    @SwiftUI.Environment(\.managedObjectContext) var managedObjectContext
    
    var body: some View {
        
        // MARK: Posts
        Section(header: Text("Posts")
            .font(.system(.caption, design: .rounded))){
                Toggle("Show Avatars", isOn: viewModel.$showAvatars)
                Toggle("Load Images", isOn: viewModel.$loadImages)
                Stepper("Scale Text \(viewModel.$fontScale.wrappedValue)%", value: self.viewModel.$fontScale, in: 100...200, step: 10)
                Toggle("Always Preview New Posts", isOn: viewModel.$confirmBeforeReply)
                Toggle("Always Animate GIFs", isOn: viewModel.$autoplayGIFs)
                Toggle("Embed Tweets", isOn: viewModel.$embedTweets)
                Toggle("Double-Tap Skips To Bottom", isOn: viewModel.$doubleTapJump)
                Toggle("Enable Haptics", isOn: viewModel.$enableHaptics)
            }
        
        // MARK: Posting
        Section(header: Text("Posting")
            .font(.system(.caption, design: .rounded))){
                Toggle("[timg] Large Images", isOn: viewModel.$autoTIMG)
            }
        
        // MARK: Threads
        Section(header: Text("Threads")
            .font(.system(.caption, design: .rounded))){
                Toggle("Show Thread Tags", isOn: viewModel.$showThreadTags)
                Toggle("Sort Unread Bookmarks First", isOn: viewModel.$sortUnreadBookmarks)
                Toggle("Sort Unread Threads First", isOn: viewModel.$sortUnreadThreads)
                Toggle("Pull For Next Page", isOn: viewModel.$pullForNext)
            }
        
        // MARK: Sidebar
        Section(header: Text("Sidebar")
            .font(.system(.caption, design: .rounded))){
                Toggle("Hide Sidebar In Landscape", isOn: viewModel.$hideSidebarInLandscape)
            }
        
        // MARK: Default Browser
        Section(footer: Text("What to open when tapping an external link. Long-press any link for more options.")) {
            NavigationLink(destination: DefaultBrowserSelector()) {
                Text("Default Browser")
            }
            Toggle("Open YouTube in YouTube", isOn: self.viewModel.$openInYoutube)
            Toggle("Open Twitter in Twitter", isOn: self.viewModel.$openInTwitter)
        }
        
        // MARK: Themes
        Section(
            header: Text("Themes").font(.system(.caption, design: .rounded)),
            footer: Text("Awful can automatically switch between light and dark themes alongside iOS.").font(.system(.caption, design: .rounded))) {
            NavigationLink(destination: SettingsThemePickerViewSwiftUI(defaultMode: Theme.Mode.light)) {
                Text("Default Light Theme")
            }
            NavigationLink(destination: SettingsThemePickerViewSwiftUI(defaultMode: Theme.Mode.dark)) {
                Text("Default Dark Theme")
            }
            NavigationLink(destination: ForumSpecificThemes().environment(\.managedObjectContext, managedObjectContext)) {
                Text("Forum-Specific Themes")
            }
            Toggle("Dark Mode", isOn: self.viewModel.$darkModeEnabled)
            Toggle("Automatic Dark Mode", isOn: self.viewModel.$automaticDarkModeEnabled)
        }
        
        // MARK: Handoff
        Section(footer: Text("Handoff allows you to continue reading threads on nearby devices.").font(.system(.caption, design: .rounded))) {
            Toggle("Handoff", isOn: self.viewModel.$handoffEnabled)
        }
        
        // MARK: Clipboard
        Section(footer: Text("Checking the clipboard for a forums URL when you open the app allows you to jump straight to a copied URL in Awful.").font(.system(.caption, design: .rounded))) {
            Toggle("Check Clipboard for URL", isOn: self.viewModel.$clipboardURLEnabled)
        }
        
        // MARK: App Icon
        Section(header: Text("App Icon").font(.system(.caption, design: .rounded))) {
            AppIconPickerView()
        }
        
        // MARK: Unread Announcements
        Section {
            Toggle("Unread announcements badge", isOn: self.viewModel.$showUnreadAnnouncements)
        }
    }
}

// MARK: SwiftUI Preview

@available(iOS 14.0, *)
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SettingsView(viewModel: .init())
        }
    }
}


// MARK: SwiftUI Helpers

extension Binding {
    func onChange(_ handler: @escaping (Value) -> Void) -> Binding<Value> {
        Binding(
            get: { self.wrappedValue },
            set: { newValue in
                self.wrappedValue = newValue
                handler(newValue)
            }
        )
    }
}

struct AwfulListStyle: ViewModifier {
    @State var bgColor = Color(Theme.defaultTheme()[color: "backgroundColor"]!)
    func body(content: Content) -> some View {
        content
            .listRowBackground(bgColor)
    }
}

struct AwfulToggleStyle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 15.0, *) {
            content
                .tint(Color(uiColor: Theme.defaultTheme()["settingsSwitchColor"]!))
        } else {
            content
        }
    }
}

extension View {
    func awfulToggleStyle() -> some View {
        modifier(AwfulToggleStyle())
    }
    func awfulListStyle() -> some View {
        modifier(AwfulListStyle())
    }
}


// MARK: UIKit embeds

struct ForumSpecificThemes: UIViewControllerRepresentable {
    @SwiftUI.Environment(\.managedObjectContext) var managedObjectContext
    
    typealias UIViewControllerType = SettingsForumSpecificThemesViewController
    
    func makeUIViewController(context: Context) -> SettingsForumSpecificThemesViewController {
        let myViewController = SettingsForumSpecificThemesViewController(context: managedObjectContext)
        // myView.delegate = context.coordinator
        return myViewController
    }
    
    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {
        // left blank
    }
    
    func makeCoordinator() -> ForumSpecificThemes.Coordinator {
        return Coordinator(self)
    }
}

extension ForumSpecificThemes {
    class Coordinator /*: SomeUIKitViewDelegate */ {
        var parent: ForumSpecificThemes
        
        init(_ parent: ForumSpecificThemes) {
            self.parent = parent
        }
        
        // Implement delegate methods here
    }
}


struct SettingsThemePickerViewSwiftUI: UIViewControllerRepresentable {
    var defaultMode: Theme.Mode
    
    typealias UIViewControllerType = SettingsThemePickerViewController
    
    func makeUIViewController(context: Context) -> SettingsThemePickerViewController {
        let myViewController = SettingsThemePickerViewController(defaultMode: defaultMode)
        // myView.delegate = context.coordinator
        return myViewController
    }
    
    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {
        // left blank
        
    }
    
    func makeCoordinator() -> SettingsThemePickerViewSwiftUI.Coordinator {
        return Coordinator(self)
    }
}

extension SettingsThemePickerViewSwiftUI {
    class Coordinator /*: SomeUIKitViewDelegate */ {
        var parent: SettingsThemePickerViewSwiftUI
        
        init(_ parent: SettingsThemePickerViewSwiftUI) {
            self.parent = parent
        }
        
        // Implement delegate methods here
    }
}


struct ProfileViewUIKit: UIViewControllerRepresentable {
    typealias UIViewControllerType = ProfileViewController
    
    var loggedInUser: User
    
    func makeUIViewController(context: Context) -> ProfileViewController {
        let myViewController = ProfileViewController(user: loggedInUser)
        // myView.delegate = context.coordinator
        return myViewController
    }
    
    func updateUIViewController(_ uiViewController: ProfileViewController, context: Context) {
        //
    }
    
}

struct DefaultBrowserSelector: UIViewControllerRepresentable {
    func updateUIViewController(_ uiViewController: SettingsDefaultBrowserController, context: Context) {
        //
    }
    
    typealias UIViewControllerType = SettingsDefaultBrowserController
    
    func makeUIViewController(context: Context) -> SettingsDefaultBrowserController {
        let myViewController = SettingsDefaultBrowserController()
        // myView.delegate = context.coordinator
        return myViewController
    }
    
}
