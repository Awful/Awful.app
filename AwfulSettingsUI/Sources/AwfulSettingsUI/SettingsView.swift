//  SettingsView.swift
//
//  Copyright 2024 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulExtensions
import AwfulSettings
import AwfulTheming
import CoreData
import NukeUI
import SwiftUI

/// The settings form.
///
/// Each section is its own view struct that declares only the `@AppStorage` keys it renders, so
/// flipping one toggle re-evaluates that section alone rather than the whole form. Keep it that
/// way: don't add `@AppStorage` properties to `SettingsView` itself.
public struct SettingsView: View {
    let appIconDataSource: AppIconDataSource
    let authenticateImgurAccount: () -> Void
    let avatarURL: URL?
    let cacheSizeText: String
    let canOpenTwitter: Bool
    let canOpenYouTube: Bool
    let currentUsername: String
    let emptyCache: () -> Void
    let goToAwfulThread: () -> Void
    let hasRegularSizeClassInLandscape: Bool
    let isMac: Bool
    let isPad: Bool
    let keyboardShortcutSections: [KeyboardShortcutSection]
    let logOut: () -> Void
    let resetSettings: () -> Void
    @Environment(\.theme) var theme

    public init(
        appIconDataSource: AppIconDataSource,
        authenticateImgurAccount: @escaping () -> Void,
        avatarURL: URL?,
        cacheSizeText: String,
        canOpenURL: @escaping (URL) -> Bool,
        currentUsername: String,
        emptyCache: @escaping () -> Void,
        goToAwfulThread: @escaping () -> Void,
        hasRegularSizeClassInLandscape: Bool,
        isMac: Bool,
        isPad: Bool,
        keyboardShortcutSections: [KeyboardShortcutSection],
        logOut: @escaping () -> Void,
        resetSettings: @escaping () -> Void
    ) {
        self.appIconDataSource = appIconDataSource
        self.authenticateImgurAccount = authenticateImgurAccount
        self.avatarURL = avatarURL
        self.cacheSizeText = cacheSizeText
        // Whether these apps are installed can't change while the screen is up, so resolve it
        // once here rather than doing a `canOpenURL` round trip on every body evaluation.
        self.canOpenTwitter = canOpenURL(URL(string: "twitter://")!)
        self.canOpenYouTube = canOpenURL(URL(string: "youtube://")!)
        self.currentUsername = currentUsername
        self.emptyCache = emptyCache
        self.goToAwfulThread = goToAwfulThread
        self.hasRegularSizeClassInLandscape = hasRegularSizeClassInLandscape
        self.isMac = isMac
        self.isPad = isPad
        self.keyboardShortcutSections = keyboardShortcutSections
        self.logOut = logOut
        self.resetSettings = resetSettings
    }

    public var body: some View {
        Form {
            AccountSection(avatarURL: avatarURL, currentUsername: currentUsername, logOut: logOut)
            FeedbackSection(goToAwfulThread: goToAwfulThread)
            PostsSection(isPad: isPad)
            PostingSection(authenticateImgurAccount: authenticateImgurAccount)
            ThreadsSection()
            if hasRegularSizeClassInLandscape {
                SidebarSection()
            }
            LinksSection(canOpenTwitter: canOpenTwitter, canOpenYouTube: canOpenYouTube)
            ThemesSection()
            RestoreLastThreadSection()
            HandoffSection()
            FrogAndGhostSection()
            ClipboardSection()
            if !isMac {
                AppIconSection(appIconDataSource: appIconDataSource)
            }
            TabsSection()
            DataManagementSection(cacheSizeText: cacheSizeText, emptyCache: emptyCache, resetSettings: resetSettings)
            if isPad || isMac {
                KeyboardShortcutsSection(sections: keyboardShortcutSections)
            }
            AcknowledgementsSection()
        }
        .backport.fontDesign(theme.roundedFonts ? .rounded : nil)
        .foregroundStyle(theme[color: "listText"]!)
        .tint(theme[color: "tint"]!)
        .backport.scrollContentBackground(.hidden)
        .background(theme[color: "background"]!)
    }
}

// MARK: - Sections

private struct AccountSection: View {
    let avatarURL: URL?
    let currentUsername: String
    let logOut: () -> Void

    var body: some View {
        Section {
            Button("Log Out", bundle: .module) { logOut() }
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
        }
        .section()
    }
}

private struct FeedbackSection: View {
    let goToAwfulThread: () -> Void
    private static let buildInfo = BuildInfo()

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

    var body: some View {
        Section {
            Button { goToAwfulThread() } label: {
                CaptionedLabel(
                    "Go to Awful’s Thread",
                    caption: "Post feedback, bug reports, and feature suggestions. Do not contact anyone who works for Something Awful about this app."
                )
            }
        } header: {
            Text(Self.buildInfo.localizedDescription)
                .header()
        }
        .section()
    }
}

private struct PostsSection: View {
    let isPad: Bool
    @AppStorage(Settings.autoplayGIFs) private var alwaysAnimateGIFs
    @AppStorage(Settings.confirmBeforeReplying) private var alwaysPreviewNewPosts
    @AppStorage(Settings.enableCustomTitlePostLayout) private var customTitlePostLayout
    @AppStorage(Settings.jumpToPostEndOnDoubleTap) private var doubleTapPostToJump
    @AppStorage(Settings.embedBlueskyPosts) private var embedBlueskyPosts
    @AppStorage(Settings.embedTweets) private var embedTweets
    @AppStorage(Settings.embedVideos) private var embedVideos
    @AppStorage(Settings.enableHaptics) private var enableHaptics
    @AppStorage(Settings.fontScale) private var fontScale
    @AppStorage(Settings.hidePostMetadataForReader) private var hidePostMetadataForReader
    @AppStorage(Settings.immersiveModeEnabled) private var immersiveModeEnabled
    @AppStorage(Settings.loadImages) private var loadImages
    @AppStorage(Settings.showAvatars) private var showAvatars

    var body: some View {
        Section {
            Toggle("Show Avatars", bundle: .module, isOn: $showAvatars)
            Toggle("Load Images", bundle: .module, isOn: $loadImages)
            Stepper("Scale Text \(fontScale.formatted())%", bundle: .module, value: $fontScale, in: 50...200, step: 10)
            Toggle("Always Preview New Posts", bundle: .module, isOn: $alwaysPreviewNewPosts)
            Toggle("Always Animate GIFs", bundle: .module, isOn: $alwaysAnimateGIFs)
            Toggle("Embed Bluesky Posts", bundle: .module, isOn: $embedBlueskyPosts)
            Toggle("Embed Tweets", bundle: .module, isOn: $embedTweets)
            Toggle("Embed Videos", bundle: .module, isOn: $embedVideos)
            Toggle("Double-Tap Post to Jump", bundle: .module, isOn: $doubleTapPostToJump)
            Toggle("Immersive Mode", bundle: .module, isOn: $immersiveModeEnabled)
            Toggle("Enable Haptics", bundle: .module, isOn: $enableHaptics)
            if isPad {
                Toggle("Enable Custom Title Post Layout", bundle: .module, isOn: $customTitlePostLayout)
            }
            Toggle(isOn: $hidePostMetadataForReader) {
                CaptionedLabel(
                    "Hide Post Metadata from Screen Reader",
                    caption: "Skips usernames, post dates, and join dates when iOS reads posts aloud (Speak Screen and VoiceOver)."
                )
            }
        } header: {
            Text("Posts", bundle: .module)
                .header()
        }
        .section()
    }
}

private struct PostingSection: View {
    let authenticateImgurAccount: () -> Void
    @AppStorage("imgur_upload_mode") private var imgurUploadMode: String = "Off"
    @AppStorage(Settings.cleanPastedURLs) private var removeTrackingFromLinks
    @AppStorage(Settings.automaticTimg) private var timgLargeImages
    @AppStorage(Settings.useNewSmiliePicker) private var useNewSmiliePicker

    var body: some View {
        Section {
            Toggle("[timg] Large Images", bundle: .module, isOn: $timgLargeImages)
            Toggle("New Smilie Picker", bundle: .module, isOn: $useNewSmiliePicker)
            Toggle(isOn: $removeTrackingFromLinks) {
                CaptionedLabel(
                    "Remove Tracking from Links",
                    caption: "Strips tracking parameters (like utm_ and fbclid) from links pasted into the composer. A Use Original button appears after each cleaned paste."
                )
            }
            Picker(selection: $imgurUploadMode) {
                Text("Off").tag("Off")
                Text("Imgur Account").tag("Imgur Account")
                Text("Anonymous").tag("Anonymous")
            } label: {
                CaptionedLabel(
                    "Imgur Uploads",
                    caption: "\"Anonymous\" submits images to Imgur without a user account. Imgur may delete these uploads without warning. Using an Imgur account is recommended."
                )
            }
            .onChange(of: imgurUploadMode) { newValue in
                if newValue == "Imgur Account" {
                    authenticateImgurAccount()
                } else {
                    clearImgurCredentials()
                }
            }
        } header: {
            Text("Posting", bundle: .module)
                .header()
        }
        .section()
    }

    private func clearImgurCredentials() {
        NotificationCenter.default.post(name: Notification.Name("ClearImgurCredentials"), object: nil)
    }
}

private struct ThreadsSection: View {
    @AppStorage(Settings.pullForNext) private var pullForNextPage
    @AppStorage(Settings.showThreadTags) private var showThreadTags
    @AppStorage(Settings.bookmarksSortedUnread) private var sortFirstUnreadBookmarks
    @AppStorage(Settings.forumThreadsSortedUnread) private var sortFirstUnreadThreads

    var body: some View {
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
    }
}

private struct SidebarSection: View {
    @AppStorage(Settings.hideSidebarInLandscape) private var hideSidebarInLandscape
    @AppStorage(Settings.swipeToRevealSidebar) private var swipeToRevealSidebar

    var body: some View {
        Section {
            Toggle("Hide Sidebar in Landscape", bundle: .module, isOn: $hideSidebarInLandscape)
            // Shown as on and locked while the sidebar hides in landscape, when the swipe is
            // always available; the stored choice is untouched so it comes back when that
            // setting is turned off again.
            Toggle(isOn: hideSidebarInLandscape ? .constant(true) : $swipeToRevealSidebar) {
                CaptionedLabel(
                    "Swipe to Reveal Sidebar",
                    caption: "Swipe right on the current page to open a hidden sidebar. Always on while Hide Sidebar in Landscape is on."
                )
            }
            .disabled(hideSidebarInLandscape)
        } header: {
            Text("Sidebar", bundle: .module)
                .header()
        }
        .section()
    }
}

private struct LinksSection: View {
    let canOpenTwitter: Bool
    let canOpenYouTube: Bool
    @AppStorage(Settings.defaultBrowser) private var defaultBrowser
    @AppStorage(Settings.openTwitterLinksInTwitter) private var openLinksInTwitter
    @AppStorage(Settings.openYouTubeLinksInYouTube) private var openLinksInYouTube

    var body: some View {
        Section {
            Picker(selection: $defaultBrowser) {
                ForEach(DefaultBrowser.allCases, id: \.rawValue) { browser in
                    Text(browser.rawValue).tag(browser)
                }
            } label: {
                CaptionedLabel(
                    "Default Browser",
                    caption: "What to open when tapping an external link. Long-press any link for more options."
                )
            }
            if canOpenYouTube {
                Toggle("Open YouTube in YouTube", bundle: .module, isOn: $openLinksInYouTube)
            }
            if canOpenTwitter {
                Toggle("Open Twitter in Twitter", bundle: .module, isOn: $openLinksInTwitter)
            }
        } header: {
            Text("Links", bundle: .module)
                .header()
        }
        .section()
    }
}

private struct ThemesSection: View {
    @AppStorage(Settings.autoDarkTheme) private var darkModeAutomatic
    @AppStorage(Settings.darkMode) private var darkModeManuallyEnabled
    @AppStorage(Settings.disableLiquidGlass) private var disableLiquidGlass
    @Environment(\.managedObjectContext) private var managedObjectContext

    var body: some View {
        Section {
            NavigationLink("Default Light Theme", bundle: .module) {
                ThemePickerView(defaultMode: .light)
                    .navigationTitle("Default Light Theme", bundle: .module)
            }
            NavigationLink("Default Dark Theme", bundle: .module) {
                ThemePickerView(defaultMode: .dark)
                    .navigationTitle("Default Dark Theme", bundle: .module)
            }
            NavigationLink("Forum-Specific Themes", bundle: .module) {
                ForumSpecificThemesView()
                    .environment(\.managedObjectContext, managedObjectContext) // Not inherited from SettingsView's environment?
                    .navigationTitle("Forum-Specific Themes", bundle: .module)
            }
            Toggle("Dark Mode", bundle: .module, isOn: $darkModeManuallyEnabled)
                .disabled(darkModeAutomatic)
            Toggle(isOn: $darkModeAutomatic) {
                CaptionedLabel(
                    "Automatic Dark Mode",
                    caption: "Awful can automatically switch between light and dark themes alongside iOS."
                )
            }
            if #available(iOS 26.0, *) {
                Toggle(isOn: $disableLiquidGlass) {
                    CaptionedLabel(
                        "Reduce Liquid Glass",
                        caption: "It can't be disabled completely, but we can revert our custom components to the original flat style and apply whatever settings available wherever possible to get rid of most of it. The back button and tab selector cannot be de-glassed. If turning this setting on, quit and relaunch the app for the best experience."
                    )
                }
            }
        } header: {
            Text("Themes", bundle: .module)
                .header()
        }
        .section()
    }
}

private struct RestoreLastThreadSection: View {
    @AppStorage(Settings.restoreLastThreadOnLaunch) private var restoreLastThreadOnLaunch

    var body: some View {
        Section {
            Toggle(isOn: $restoreLastThreadOnLaunch) {
                CaptionedLabel(
                    "Restore Last Thread on Launch",
                    caption: "When on, Awful reopens the thread you were last reading when you relaunch. When off, Awful returns to the tab you were last using."
                )
            }
        }
        .section()
    }
}

private struct HandoffSection: View {
    @AppStorage(Settings.handoffEnabled) private var handoffEnabled

    var body: some View {
        Section {
            Toggle(isOn: $handoffEnabled) {
                CaptionedLabel(
                    "Handoff",
                    caption: "Handoff allows you to continue reading threads on nearby devices."
                )
            }
        }
        .section()
    }
}

private struct FrogAndGhostSection: View {
    @AppStorage(Settings.frogAndGhostEnabled) private var frogAndGhostEnabled

    var body: some View {
        Section {
            Toggle("Show End-of-Thread Frog and Dead Tweet Ghost", bundle: .module, isOn: $frogAndGhostEnabled)
        }
        .section()
    }
}

private struct ClipboardSection: View {
    @AppStorage(Settings.clipboardURLEnabled) private var checkClipboardForURLOnBecomeActive

    var body: some View {
        Section {
            Toggle(isOn: $checkClipboardForURLOnBecomeActive) {
                CaptionedLabel(
                    "Check Clipboard for URL",
                    caption: "Checking the clipboard for a forums URL when you open the app allows you to jump straight to a copied URL in Awful."
                )
            }
        }
        .section()
    }
}

private struct AppIconSection: View {
    @ObservedObject var appIconDataSource: AppIconDataSource
    @Environment(\.theme) private var theme

    var body: some View {
        Section {
            NavigationLink {
                AppIconGridView(appIconDataSource: appIconDataSource)
                    .environment(\.theme, theme) // Not inherited?
            } label: {
                HStack {
                    Text("App Icon", bundle: .module)
                    Spacer()
                    appIconDataSource.imageLoader(appIconDataSource.selected)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 29, height: 29)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
        } header: {
            Text("App Icon", bundle: .module)
                .header()
        }
        .section()
    }
}

private struct TabsSection: View {
    @AppStorage(Settings.showUnreadAnnouncementsBadge) private var showUnreadAnnouncementsBadge

    var body: some View {
        Section {
            Toggle("Unread Announcements Badge", bundle: .module, isOn: $showUnreadAnnouncementsBadge)
        } header: {
            Text("Tabs", bundle: .module)
                .header()
        }
        .section()
    }
}

private struct DataManagementSection: View {
    let cacheSizeText: String
    let emptyCache: () -> Void
    let resetSettings: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        Section {
            Button { emptyCache() } label: {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("Clear Cache", bundle: .module)
                        Spacer()
                        Text(cacheSizeText)
                            .foregroundStyle(theme[color: "listSecondaryText"]!)
                    }
                    Text("Clearing the cache removes downloaded images, web data, and cached forums, threads, and posts.", bundle: .module)
                        .font(.footnote)
                        .foregroundStyle(theme[color: "listSecondaryText"]!)
                }
            }
            Button { resetSettings() } label: {
                CaptionedLabel(
                    "Reset All Settings",
                    caption: "Resetting settings restores all preferences to their defaults."
                )
            }
        } header: {
            Text("Data Management", bundle: .module)
                .header()
        }
        .section()
    }
}

private struct KeyboardShortcutsSection: View {
    let sections: [KeyboardShortcutSection]
    @Environment(\.theme) private var theme

    var body: some View {
        Section {
            NavigationLink("Keyboard Shortcuts", bundle: .module) {
                KeyboardShortcutsView(sections: sections)
                    .navigationTitle("Keyboard Shortcuts", bundle: .module)
                    .environment(\.theme, theme) // Not inherited?
            }
        } header: {
            Text("Keyboard", bundle: .module)
                .header()
        }
        .section()
    }
}

private struct AcknowledgementsSection: View {
    @Environment(\.theme) private var theme

    var body: some View {
        Section {
            NavigationLink("Acknowledgements", bundle: .module) {
                AcknowledgementsView()
                    .navigationTitle("Acknowledgements", bundle: .module)
                    .environment(\.theme, theme) // Not inherited?
            }
        } header: {
            Text("Thank You", bundle: .module)
                .header()
        }
        .section()
    }
}

// MARK: - Shared pieces

/// A row label with explanatory caption text beneath the title, in place of a section footer.
private struct CaptionedLabel: View {
    let title: LocalizedStringKey
    let caption: LocalizedStringKey
    @Environment(\.theme) private var theme

    init(_ title: LocalizedStringKey, caption: LocalizedStringKey) {
        self.title = title
        self.caption = caption
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title, bundle: .module)
            Text(caption, bundle: .module)
                .font(.footnote)
                .foregroundStyle(theme[color: "listSecondaryText"]!)
        }
    }
}

private extension View {
    func header() -> some View {
        modifier(HeaderFooterModifier(weight: .semibold))
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
            appIconDataSource: .preview,
            authenticateImgurAccount: { print("authenticating with Imgur") },
            avatarURL: nil,
            cacheSizeText: "42.3 MB",
            canOpenURL: { _ in true },
            currentUsername: "Random Newbie",
            emptyCache: { print("emptying cache") },
            goToAwfulThread: { print("navigating to Awful's thread") },
            hasRegularSizeClassInLandscape: true,
            isMac: false,
            isPad: true,
            keyboardShortcutSections: [
                KeyboardShortcutSection(title: "General", shortcuts: [
                    KeyboardShortcutRow(title: "Refresh the detail pane", keys: "⌘R"),
                ]),
            ],
            logOut: { print("logging out") },
            resetSettings: { print("resetting settings") }
        )
        .navigationTitle(Text(verbatim: "Settings"))
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.theme, Theme.defaultTheme())
    }
}
