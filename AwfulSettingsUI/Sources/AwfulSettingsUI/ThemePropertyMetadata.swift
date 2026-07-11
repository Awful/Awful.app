//  ThemePropertyMetadata.swift
//
//  Copyright 2025 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulTheming
import Foundation

/// Describes the type and category of a theme property for the custom theme editor.
enum ThemePropertyType {
    case color
    case boolean
    case string
    case stringEnum([String])
    case number
    case fontName
}

/// A section grouping for theme properties in the editor UI.
enum ThemePropertyCategory: String, CaseIterable {
    case general = "General"
    case lists = "Lists"
    case navigation = "Navigation & Toolbars"
    case posts = "Posts"
    case sheets = "Sheets"
    case tagPicker = "Tag Picker"
    case badges = "Unread Badges"
    case actionIcons = "Action Icons"
    case lotties = "Animations"
}

/// Metadata for a single theme property.
struct ThemeProperty {
    let key: String
    let displayName: String
    let category: ThemePropertyCategory
    let type: ThemePropertyType
}

/// All editable theme properties, organized by category.
/// CSS keys (postsViewCSS) are excluded — they're handled separately in the stylesheet editor.
let allThemeProperties: [ThemeProperty] = [
    // MARK: General
    ThemeProperty(key: "mode", displayName: "Mode", category: .general, type: .stringEnum(["light", "dark"])),
    ThemeProperty(key: "menuAppearance", displayName: "Menu Appearance", category: .general, type: .stringEnum(["light", "dark"])),
    ThemeProperty(key: "statusBarBackground", displayName: "Status Bar Background", category: .general, type: .stringEnum(["light", "dark"])),
    ThemeProperty(key: "scrollIndicatorStyle", displayName: "Scroll Indicator Style", category: .general, type: .stringEnum(["Dark", "Light"])),
    ThemeProperty(key: "keyboardAppearance", displayName: "Keyboard Appearance", category: .general, type: .stringEnum(["Light", "Dark"])),
    ThemeProperty(key: "roundedFonts", displayName: "Rounded Fonts", category: .general, type: .boolean),
    ThemeProperty(key: "tintColor", displayName: "Tint Color", category: .general, type: .color),
    ThemeProperty(key: "backgroundColor", displayName: "Background Color", category: .general, type: .color),
    ThemeProperty(key: "placeholderTextColor", displayName: "Placeholder Text Color", category: .general, type: .color),
    ThemeProperty(key: "favoriteStarTintColor", displayName: "Favorite Star Tint", category: .general, type: .color),
    ThemeProperty(key: "settingsSwitchColor", displayName: "Settings Switch Color", category: .general, type: .color),
    ThemeProperty(key: "actionIconTintColor", displayName: "Action Icon Tint", category: .general, type: .color),
    ThemeProperty(key: "descriptiveColor", displayName: "Theme Preview Color", category: .general, type: .color),

    // MARK: Lists
    ThemeProperty(key: "listFontName", displayName: "Font Name", category: .lists, type: .fontName),
    ThemeProperty(key: "listTextColor", displayName: "Text Color", category: .lists, type: .color),
    ThemeProperty(key: "listSecondaryTextColor", displayName: "Secondary Text Color", category: .lists, type: .color),
    ThemeProperty(key: "listHeaderTextColor", displayName: "Header Text Color", category: .lists, type: .color),
    ThemeProperty(key: "listHeaderBackgroundColor", displayName: "Header Background", category: .lists, type: .color),
    ThemeProperty(key: "listSeparatorColor", displayName: "Separator Color", category: .lists, type: .color),
    ThemeProperty(key: "listBackgroundColor", displayName: "Background Color", category: .lists, type: .color),
    ThemeProperty(key: "listSelectedBackgroundColor", displayName: "Selected Background", category: .lists, type: .color),
    ThemeProperty(key: "ratingIconEmptyColor", displayName: "Rating Icon Empty Color", category: .lists, type: .color),
    ThemeProperty(key: "expansionTintColor", displayName: "Expansion Tint", category: .lists, type: .color),
    ThemeProperty(key: "threadListPageIconColor", displayName: "Page Icon Color", category: .lists, type: .color),
    ThemeProperty(key: "unreadPostCountFontSizeAdjustment", displayName: "Unread Count Size Adj.", category: .lists, type: .number),
    ThemeProperty(key: "messageListSenderFontSizeAdjustment", displayName: "Msg Sender Size Adj.", category: .lists, type: .number),
    ThemeProperty(key: "messageListSentDateFontSizeAdjustment", displayName: "Msg Date Size Adj.", category: .lists, type: .number),
    ThemeProperty(key: "messageListSubjectFontSizeAdjustment", displayName: "Msg Subject Size Adj.", category: .lists, type: .number),

    // MARK: Navigation & Toolbars
    ThemeProperty(key: "showRootTabBarLabel", displayName: "Show Tab Bar Labels", category: .navigation, type: .boolean),
    ThemeProperty(key: "tabBarTintColor", displayName: "Tab Bar Tint", category: .navigation, type: .color),
    ThemeProperty(key: "tabBarIconNormalColor", displayName: "Tab Bar Icon Normal", category: .navigation, type: .color),
    ThemeProperty(key: "tabBarIconSelectedColor", displayName: "Tab Bar Icon Selected", category: .navigation, type: .color),
    ThemeProperty(key: "tabBarBackgroundColor", displayName: "Tab Bar Background", category: .navigation, type: .color),
    ThemeProperty(key: "tabBarIsTranslucent", displayName: "Tab Bar Translucent", category: .navigation, type: .boolean),
    ThemeProperty(key: "navigationBarTextColor", displayName: "Nav Bar Text", category: .navigation, type: .color),
    ThemeProperty(key: "navigationBarTintColor", displayName: "Nav Bar Tint", category: .navigation, type: .color),
    ThemeProperty(key: "navigationBarShadowOpacity", displayName: "Nav Bar Shadow Opacity", category: .navigation, type: .number),
    ThemeProperty(key: "toolbarTextColor", displayName: "Toolbar Text", category: .navigation, type: .color),
    ThemeProperty(key: "toolbarTintColor", displayName: "Toolbar Tint", category: .navigation, type: .color),
    ThemeProperty(key: "bottomBarTopBorderColor", displayName: "Bottom Bar Border", category: .navigation, type: .color),
    ThemeProperty(key: "topBarBottomBorderColor", displayName: "Top Bar Border", category: .navigation, type: .color),

    // MARK: Posts
    ThemeProperty(key: "postsTweetTheme", displayName: "Tweet Theme", category: .posts, type: .stringEnum(["light", "dark"])),
    ThemeProperty(key: "postsLoadingViewTintColor", displayName: "Loading View Tint", category: .posts, type: .color),
    ThemeProperty(key: "postsLoadingViewType", displayName: "Loading View Type", category: .posts, type: .string),
    ThemeProperty(key: "postsPullForNextColor", displayName: "Pull for Next Color", category: .posts, type: .color),
    ThemeProperty(key: "postsTopBarTextColor", displayName: "Top Bar Text", category: .posts, type: .color),
    ThemeProperty(key: "postsTopBarBackgroundColor", displayName: "Top Bar Background", category: .posts, type: .color),
    ThemeProperty(key: "postsViewThreadTitleFontSize", displayName: "Thread Title Font Size", category: .posts, type: .number),
    ThemeProperty(key: "postTitleFontSizeAdjustmentPhone", displayName: "Title Size Adj. (Phone)", category: .posts, type: .number),
    ThemeProperty(key: "postTitleFontWeightPhone", displayName: "Title Weight (Phone)", category: .posts, type: .stringEnum(FontWeight.allCases.map(\.rawValue))),
    ThemeProperty(key: "postTitleFontSizeAdjustmentPad", displayName: "Title Size Adj. (iPad)", category: .posts, type: .number),
    ThemeProperty(key: "postTitleFontWeightPad", displayName: "Title Weight (iPad)", category: .posts, type: .stringEnum(FontWeight.allCases.map(\.rawValue))),

    // MARK: Sheets
    ThemeProperty(key: "sheetBackgroundColor", displayName: "Background", category: .sheets, type: .color),
    ThemeProperty(key: "sheetTitleColor", displayName: "Title Color", category: .sheets, type: .color),
    ThemeProperty(key: "sheetTitleBackgroundColor", displayName: "Title Background", category: .sheets, type: .color),
    ThemeProperty(key: "sheetTextColor", displayName: "Text Color", category: .sheets, type: .color),
    ThemeProperty(key: "sheetDimColor", displayName: "Dim Color", category: .sheets, type: .color),

    // MARK: Tag Picker
    ThemeProperty(key: "tagPickerTextColor", displayName: "Text Color", category: .tagPicker, type: .color),
    ThemeProperty(key: "tagPickerBackgroundColor", displayName: "Background", category: .tagPicker, type: .color),

    // MARK: Unread Badges
    ThemeProperty(key: "unreadBadgeBlueColor", displayName: "Blue", category: .badges, type: .color),
    ThemeProperty(key: "unreadBadgeRedColor", displayName: "Red", category: .badges, type: .color),
    ThemeProperty(key: "unreadBadgeOrangeColor", displayName: "Orange", category: .badges, type: .color),
    ThemeProperty(key: "unreadBadgeYellowColor", displayName: "Yellow", category: .badges, type: .color),
    ThemeProperty(key: "unreadBadgeGreenColor", displayName: "Green", category: .badges, type: .color),
    ThemeProperty(key: "unreadBadgeCyanColor", displayName: "Cyan", category: .badges, type: .color),
    ThemeProperty(key: "unreadBadgePurpleColor", displayName: "Purple", category: .badges, type: .color),
    ThemeProperty(key: "unreadBadgeGrayColor", displayName: "Gray", category: .badges, type: .color),

    // MARK: Action Icons
    ThemeProperty(key: "addBookmarkIconColor", displayName: "Add Bookmark", category: .actionIcons, type: .color),
    ThemeProperty(key: "removeBookmarkIconColor", displayName: "Remove Bookmark", category: .actionIcons, type: .color),
    ThemeProperty(key: "copyURLIconColor", displayName: "Copy URL", category: .actionIcons, type: .color),
    ThemeProperty(key: "editPostIconColor", displayName: "Edit Post", category: .actionIcons, type: .color),
    ThemeProperty(key: "ignoreUserIconColor", displayName: "Ignore User", category: .actionIcons, type: .color),
    ThemeProperty(key: "unignoreUserIconColor", displayName: "Unignore User", category: .actionIcons, type: .color),
    ThemeProperty(key: "jumpToFirstPageIconColor", displayName: "Jump to First Page", category: .actionIcons, type: .color),
    ThemeProperty(key: "jumpToLastPageIconColor", displayName: "Jump to Last Page", category: .actionIcons, type: .color),
    ThemeProperty(key: "markUnreadIconColor", displayName: "Mark Unread", category: .actionIcons, type: .color),
    ThemeProperty(key: "markReadUpToHereIconColor", displayName: "Mark Read Up To Here", category: .actionIcons, type: .color),
    ThemeProperty(key: "profileIconColor", displayName: "Profile", category: .actionIcons, type: .color),
    ThemeProperty(key: "quoteIconColor", displayName: "Quote", category: .actionIcons, type: .color),
    ThemeProperty(key: "rapSheetIconColor", displayName: "Rap Sheet", category: .actionIcons, type: .color),
    ThemeProperty(key: "sendPMIconColor", displayName: "Send PM", category: .actionIcons, type: .color),
    ThemeProperty(key: "singleUserIconColor", displayName: "Single User", category: .actionIcons, type: .color),
    ThemeProperty(key: "voteIconColor", displayName: "Vote", category: .actionIcons, type: .color),

    // MARK: Animations
    ThemeProperty(key: "getOutFrogColor", displayName: "Get Out Frog", category: .lotties, type: .color),
    ThemeProperty(key: "nigglyColor", displayName: "Niggly", category: .lotties, type: .color),
]

/// Theme properties grouped by category.
let themePropertiesByCategory: [(ThemePropertyCategory, [ThemeProperty])] = {
    var grouped: [ThemePropertyCategory: [ThemeProperty]] = [:]
    for prop in allThemeProperties {
        grouped[prop.category, default: []].append(prop)
    }
    return ThemePropertyCategory.allCases.compactMap { category in
        guard let props = grouped[category], !props.isEmpty else { return nil }
        return (category, props)
    }
}()
