import SwiftUI
import AwfulSettings
import AwfulTheming

struct PostsPageSettingsView: View {
    @AppStorage(Settings.showAvatars.key) private var showAvatars: Bool = Settings.showAvatars.default
    @AppStorage(Settings.loadImages.key) private var showImages: Bool = Settings.loadImages.default
    @AppStorage(Settings.fontScale.key) private var fontScale: Double = Settings.fontScale.default
    @AppStorage(Settings.autoDarkTheme.key) private var automaticDarkTheme: Bool = Settings.autoDarkTheme.default
    @AppStorage(Settings.darkMode.key) private var darkMode: Bool = Settings.darkMode.default
    @AppStorage(Settings.enableHaptics.key) private var enableHaptics: Bool = Settings.enableHaptics.default
    
    @SwiftUI.Environment(\.theme) private var theme
    @SwiftUI.Environment(\.dismiss) private var dismiss
    
    private var fontScaleFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        return formatter
    }
    
    private var fontScalePercentage: String {
        fontScaleFormatter.string(from: (fontScale / 100) as NSNumber) ?? ""
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Compact header
                HStack {
                    Text("Settings")
                        .font(.headline)
                        .foregroundColor(headerTextColor)
                    Spacer()
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(tintColor)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(headerBackgroundColor)
                
                // Settings content
                VStack(spacing: 20) {
                    // Avatars and Images row
                    HStack(spacing: 40) {
                        SettingToggle(
                            title: "Avatars",
                            isOn: $showAvatars
                        )
                        
                        SettingToggle(
                            title: "Images", 
                            isOn: $showImages
                        )
                        
                        Spacer()
                    }
                    
                    // Font scale
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Scale Text \(fontScalePercentage)")
                                .foregroundColor(textColor)
                            Spacer()
                        }
                        
                        HStack {
                            Button("-") {
                                if enableHaptics {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                }
                                fontScale = max(50, fontScale - 10)
                            }
                            .foregroundColor(tintColor)
                            .frame(width: 44, height: 44)
                            
                            Slider(value: $fontScale, in: 50...200, step: 10)
                                .accentColor(tintColor)
                            
                            Button("+") {
                                if enableHaptics {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                }
                                fontScale = min(200, fontScale + 10)
                            }
                            .foregroundColor(tintColor)
                            .frame(width: 44, height: 44)
                        }
                    }
                    
                    // Dark mode settings
                    VStack(spacing: 16) {
                        SettingToggle(
                            title: "Automatic Dark Mode",
                            isOn: $automaticDarkTheme
                        )
                        
                        if !automaticDarkTheme {
                            SettingToggle(
                                title: "Dark Mode",
                                isOn: $darkMode
                            )
                        }
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
            }
            .background(backgroundColor)
        }
        .navigationBarHidden(true)
        .onChange(of: showAvatars) { _ in
            if enableHaptics {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
        }
        .onChange(of: showImages) { _ in
            if enableHaptics {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
        }
        .onChange(of: automaticDarkTheme) { _ in
            if enableHaptics {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
        }
        .onChange(of: darkMode) { _ in
            if enableHaptics {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
        }
    }
    
    // MARK: - Theme Colors
    private var backgroundColor: Color {
        Color(theme[uicolor: "sheetBackgroundColor"] ?? UIColor.systemBackground)
    }
    
    private var headerBackgroundColor: Color {
        Color(theme[uicolor: "sheetTitleBackgroundColor"] ?? UIColor.systemGray6)
    }
    
    private var headerTextColor: Color {
        Color(theme[uicolor: "sheetTitleColor"] ?? UIColor.label)
    }
    
    private var textColor: Color {
        Color(theme[uicolor: "sheetTextColor"] ?? UIColor.label)
    }
    
    private var tintColor: Color {
        Color(theme[uicolor: "settingsSwitchColor"] ?? UIColor.systemBlue)
    }
}

// MARK: - Setting Toggle Component
private struct SettingToggle: View {
    let title: String
    @Binding var isOn: Bool
    @SwiftUI.Environment(\.theme) private var theme
    
    private var textColor: Color {
        Color(theme[uicolor: "sheetTextColor"] ?? UIColor.label)
    }
    
    private var tintColor: Color {
        Color(theme[uicolor: "settingsSwitchColor"] ?? UIColor.systemBlue)
    }
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(textColor)
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(SwitchToggleStyle(tint: tintColor))
        }
    }
}

// MARK: - Preview
#Preview {
    PostsPageSettingsView()
        .environment(\.theme, Theme.defaultTheme())
} 
