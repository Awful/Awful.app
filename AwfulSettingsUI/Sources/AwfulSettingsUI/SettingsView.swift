//  SettingsView.swift
//
//  Copyright 2024 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulExtensions
import AwfulSettings
import AwfulTheming
import NukeUI
import SwiftUI

public struct SettingsView<
    AcknowledgementsView: View,
    DefaultThemePickerView: View,
    ForumSpecificThemesView: View
>: View {
    @AppStorage(Settings.autoplayGIFs) private var alwaysAnimateGIFs
    @AppStorage(Settings.confirmBeforeReplying) private var alwaysPreviewNewPosts
    @AppStorage(Settings.clipboardURLEnabled) private var checkClipboardForURLOnBecomeActive
    @AppStorage(Settings.enableCustomTitlePostLayout) private var customTitlePostLayout
    @AppStorage(Settings.autoDarkTheme) private var darkModeAutomatic
    @AppStorage(Settings.darkMode) private var darkModeManuallyEnabled
    @AppStorage(Settings.defaultBrowser) private var defaultBrowser
    @AppStorage(Settings.jumpToPostEndOnDoubleTap) private var doubleTapPostToJump
    @AppStorage(Settings.embedTweets) private var embedTweets
    @AppStorage(Settings.enableHaptics) private var enableHaptics
    @AppStorage(Settings.fontScale) private var fontScale
    @AppStorage(Settings.frogAndGhostEnabled) private var frogAndGhostEnabled
    @AppStorage(Settings.handoffEnabled) private var handoffEnabled
    @AppStorage(Settings.hideSidebarInLandscape) private var hideSidebarInLandscape
    @AppStorage(Settings.loadImages) private var loadImages
    @AppStorage(Settings.openTwitterLinksInTwitter) private var openLinksInTwitter
    @AppStorage(Settings.openYouTubeLinksInYouTube) private var openLinksInYouTube
    @AppStorage(Settings.pullForNext) private var pullForNextPage
    @AppStorage(Settings.showAvatars) private var showAvatars
    @AppStorage(Settings.showThreadTags) private var showThreadTags
    @AppStorage(Settings.showUnreadAnnouncementsBadge) private var showUnreadAnnouncementsBadge
    @AppStorage(Settings.bookmarksSortedUnread) private var sortFirstUnreadBookmarks
    @AppStorage(Settings.forumThreadsSortedUnread) private var sortFirstUnreadThreads
    @AppStorage(Settings.automaticTimg) private var timgLargeImages

    let appIconDataSource: AppIconDataSource
    let avatarURL: URL?
    let buildInfo = BuildInfo()
    let canOpenURL: (URL) -> Bool
    let currentUsername: String
    let emptyCache: () -> Void
    let goToAwfulThread: () -> Void
    let hasRegularSizeClassInLandscape: Bool
    let isPad: Bool
    let logOut: () -> Void
    let makeAcknowledgements: () -> AcknowledgementsView
    let makeDefaultThemePicker: (Theme.Mode) -> DefaultThemePickerView
    let makeForumSpecificThemes: () -> ForumSpecificThemesView
    @Environment(\.theme) var theme

    struct BuildInfo {
        let build: String?
        let name: String
        let version: String?

        init(_ bundle: Bundle = .main) {
            build = bundle.version
            name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String) ?? bundle.localizedName
            version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        }

        var localizedDescription: String {
            // Using default localization keys makes these unintelligible as they're almost entirely placeholders.
            if let build, let version {
                String(localized: "appname=\(name) version=\(version) build=\(build)", bundle: .module)
            } else if let build {
                String(localized: "appname=\(name) build=\(build)", bundle: .module)
            } else if let version {
                String(localized: "appname=\(name) version=\(version)", bundle: .module)
            } else {
                name
            }
        }
    }

    public init(
        appIconDataSource: AppIconDataSource,
        avatarURL: URL?,
        canOpenURL: @escaping (URL) -> Bool,
        currentUsername: String,
        emptyCache: @escaping () -> Void,
        goToAwfulThread: @escaping () -> Void,
        hasRegularSizeClassInLandscape: Bool,
        isPad: Bool,
        logOut: @escaping () -> Void,
        makeAcknowledgements: @escaping () -> AcknowledgementsView,
        makeDefaultThemePicker: @escaping (Theme.Mode) -> DefaultThemePickerView,
        makeForumSpecificThemes: @escaping () -> ForumSpecificThemesView
    ) {
        self.appIconDataSource = appIconDataSource
        self.avatarURL = avatarURL
        self.canOpenURL = canOpenURL
        self.currentUsername = currentUsername
        self.emptyCache = emptyCache
        self.goToAwfulThread = goToAwfulThread
        self.hasRegularSizeClassInLandscape = hasRegularSizeClassInLandscape
        self.isPad = isPad
        self.logOut = logOut
        self.makeAcknowledgements = makeAcknowledgements
        self.makeDefaultThemePicker = makeDefaultThemePicker
        self.makeForumSpecificThemes = makeForumSpecificThemes
    }

    public var body: some View {
        Form {
            Section {
                Button("Log Out", bundle: .module) { logOut() }
                Button("Empty Cache", bundle: .module) { emptyCache() }
            } header: {
                VStack(alignment: .leading) {
                    Group {
                        if let avatarURL {
                            LazyImage(url: avatarURL) {
                                if let image = $0.image {
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                }
                            }
                        }
                    }
                    .frame(height: 60)

                    Text(currentUsername)
                }
                .header()
            } footer: {
                Text("Logging out erases all cached forums, threads, and posts.", bundle: .module)
                    .footer()
            }
            .section()

            Section {
                Button("Go to Awful’s Thread", bundle: .module) { goToAwfulThread() }
            } header: {
                Text(buildInfo.localizedDescription)
                    .header()
            } footer: {
                Text("Post feedback, bug reports, and feature suggestions. Do not contact anyone who works for Something Awful about this app.", bundle: .module)
                    .footer()
            }
            .section()

            Section {
                Toggle("Show Avatars", bundle: .module, isOn: $showAvatars)
                Toggle("Load Images", bundle: .module, isOn: $loadImages)
                Stepper("Scale Text \(fontScale.formatted())%", bundle: .module, value: $fontScale, in: 50...200, step: 10)
                Toggle("Always Preview New Posts", bundle: .module, isOn: $alwaysPreviewNewPosts)
                Toggle("Always Animate GIFs", bundle: .module, isOn: $alwaysAnimateGIFs)
                Toggle("Embed Tweets", bundle: .module, isOn: $embedTweets)
                Toggle("Double-Tap Post to Jump", bundle: .module, isOn: $doubleTapPostToJump)
                Toggle("Enable Haptics", bundle: .module, isOn: $enableHaptics)
                if isPad {
                    Toggle("Enable Custom Title Post Layout", bundle: .module, isOn: $customTitlePostLayout)
                }
            } header: {
                Text("Posts", bundle: .module)
                    .header()
            }
            .section()

            Section {
                Toggle("[timg] Large Images", bundle: .module, isOn: $timgLargeImages)
            } header: {
                Text("Posting", bundle: .module)
                    .header()
            }
            .section()

            Section {
                Toggle("Show Thread Tags", bundle: .module, isOn: $showThreadTags)
                Toggle("Sort Unread Bookmarks First", bundle: .module, isOn: $sortFirstUnreadBookmarks)
                Toggle("Sort Unread Threads First", bundle: .module, isOn: $sortFirstUnreadThreads)
                Toggle("Pull for Next Page", bundle: .module, isOn: $pullForNextPage)
            } header: {
                Text("Threads", bundle: .module)
                    .header()
            }
            .section()

            if hasRegularSizeClassInLandscape {
                Section {
                    Toggle("Hide Sidebar in Landscape", bundle: .module, isOn: $hideSidebarInLandscape)
                } header: {
                    Text("Sidebar", bundle: .module)
                        .header()
                }
                .section()
            }

            Section {
                Picker("Default Browser", bundle: .module, selection: $defaultBrowser) {
                    ForEach(DefaultBrowser.allCases, id: \.rawValue) { browser in
                        Text(browser.rawValue).tag(browser)
                    }
                }
                if canOpenURL(URL("youtube://")) {
                    Toggle("Open YouTube in YouTube", bundle: .module, isOn: $openLinksInYouTube)
                }
                if canOpenURL(URL("twitter://")) {
                    Toggle("Open Twitter in Twitter", bundle: .module, isOn: $openLinksInTwitter)
                }
            } header: {
                Text("Links", bundle: .module)
                    .header()
            } footer: {
                Text("What to open when tapping an external link. Long-press any link for more options.", bundle: .module)
                    .footer()
            }
            .section()

            Section {
                NavigationLink("Default Light Theme", bundle: .module) {
                    makeDefaultThemePicker(.light)
                        .navigationTitle("Default Light Theme", bundle: .module)
                }
                NavigationLink("Default Dark Theme", bundle: .module) {
                    makeDefaultThemePicker(.dark)
                        .navigationTitle("Default Dark Theme", bundle: .module)
                }
                NavigationLink("Forum-Specific Themes", bundle: .module) {
                    makeForumSpecificThemes()
                        .navigationTitle("Forum-Specific Themes", bundle: .module)
                }
                Toggle("Dark Mode", bundle: .module, isOn: $darkModeManuallyEnabled)
                    .disabled(darkModeAutomatic)
                Toggle("Automatic Dark Mode", bundle: .module, isOn: $darkModeAutomatic)
            } header: {
                Text("Themes", bundle: .module)
                    .header()
            } footer: {
                Text("Awful can automatically switch between light and dark themes alongside iOS.", bundle: .module)
                    .footer()
            }
            .section()

            Section {
                Toggle("Handoff", bundle: .module, isOn: $handoffEnabled)
            } footer: {
                Text("Handoff allows you to continue reading threads on nearby devices.", bundle: .module)
                    .footer()
            }
            .section()

            Section {
                Toggle("Show End-of-Thread Frog and Dead Tweet Ghost", bundle: .module, isOn: $frogAndGhostEnabled)
            }
            .section()

            Section {
                Toggle("Check Clipboard for URL", bundle: .module, isOn: $checkClipboardForURLOnBecomeActive)
            } footer: {
                Text("Checking the clipboard for a forums URL when you open th eapp allows you to jump straight to a copied URL in Awful.", bundle: .module)
                    .footer()
            }
            .section()

            Section {
                AppIconPicker(appIconDataSource: appIconDataSource)
            } header: {
                Text("App Icon", bundle: .module)
                    .header()
            }
            .section()

            Section {
                Toggle("Unread Announcements Badge", bundle: .module, isOn: $showUnreadAnnouncementsBadge)
            } header: {
                Text("Tabs", bundle: .module)
                    .header()
            }
            .section()

            Section {
                NavigationLink("Acknowledgements", bundle: .module) {
                    makeAcknowledgements()
                        .navigationTitle("Acknowledgements", bundle: .module)
                }
            } header: {
                Text("Thank You", bundle: .module)
                    .header()
            }
            .section()
        }
        .foregroundStyle(theme[color: "listText"]!)
        .tint(theme[color: "tint"]!)
        .backport.scrollContentBackground(.hidden)
        .background(theme[color: "background"]!)
        .task { await appIconDataSource.loadAppIcons() }
    }
}

private extension View {
    func header() -> some View {
        modifier(HeaderFooterModifier(weight: .semibold))
    }
    func footer() -> some View {
        modifier(HeaderFooterModifier(weight: .regular))
    }
    func section() -> some View {
        modifier(SectionModifier())
    }
}
private struct HeaderFooterModifier: ViewModifier {
    @Environment(\.theme) var theme
    let weight: Font.Weight?
    func body(content: Content) -> some View {
        content
            .backport.fontWeight(weight)
            .foregroundStyle(theme[color: "listSecondaryText"]!)
            .textCase(nil)
    }
}
private struct SectionModifier: ViewModifier {
    @Environment(\.theme) var theme
    func body(content: Content) -> some View {
        content.listRowBackground(theme[color: "listBackground"]!)
    }
}

#Preview {
    NavigationView {
        SettingsView(
            appIconDataSource: .init(
                iconsLoader: { (1...).prefix(12).map { .init("test\($0)") } },
                imageLoader: { _ in Image(systemName: "questionmark.app") },
                selectedIconName: .init("test2"),
                setCurrentIconName: { _ in }
            ),
            avatarURL: nil,
            canOpenURL: { _ in true },
            currentUsername: "Random Newbie",
            emptyCache: { print("emptying cache") },
            goToAwfulThread: { print("navigating to Awful's thread") },
            hasRegularSizeClassInLandscape: true,
            isPad: true,
            logOut: { print("logging out") },
            makeAcknowledgements: { Text(verbatim: "tyvm") },
            makeDefaultThemePicker: { Text(verbatim: "Default \("\($0)") Picker") },
            makeForumSpecificThemes: { Text(verbatim: "Forum-specific themes!") }
        )
        .navigationTitle(Text(verbatim: "Settings"))
        .environment(\.theme, Theme.defaultTheme(mode: .dark))
    }
}
