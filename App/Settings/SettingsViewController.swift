//  Copyright 2024 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import AwfulSettings
import AwfulSettingsUI
import AwfulTheming
import Combine
import CoreData
import os
import SwiftUI
import UniformTypeIdentifiers

private let Log = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "SettingsViewController")

final class SettingsViewController: HostingController<SettingsContainerView> {
    let managedObjectContext: NSManagedObjectContext
    private var cacheSizeText: CurrentValueSubject<String, Never> = .init("Calculating…")

    init(managedObjectContext: NSManagedObjectContext) {
        self.managedObjectContext = managedObjectContext

        let currentUser = managedObjectContext.performAndWait {
            User.objectForKey(objectKey: UserKey(
                userID: UserDefaults.standard.value(for: Settings.userID)!,
                username: UserDefaults.standard.value(for: Settings.username)
            ), in: managedObjectContext)
        }

        // Allows indirect passing of `self` into root view actions before super.init().
        class UnownedBox {
            unowned var contents: SettingsViewController!
        }
        let box = UnownedBox()
        let cacheSizeText = CurrentValueSubject<String, Never>("Calculating…")

        super.init(rootView: SettingsContainerView(
            appIconDataSource: makeAppIconDataSource(),
            cacheSizeText: cacheSizeText,
            currentUser: currentUser,
            emptyCache: { box.contents.emptyCache() },
            exportSettings: { box.contents.exportSettings() },
            goToAwfulThread: { box.contents.goToAwfulThread() },
            // Not sure how to tell for real, seems like a decent proxy?
            hasRegularSizeClassInLandscape: UIDevice.current.userInterfaceIdiom == .pad || UIScreen.main.scale > 2,
            importSettings: { box.contents.importSettings() },
            isMac: ProcessInfo.processInfo.isMacCatalystApp,
            isPad: UIDevice.current.userInterfaceIdiom == .pad,
            logOut: { AppDelegate.instance.logOut() },
            managedObjectContext: managedObjectContext,
            resetSettings: { box.contents.resetSettings() }
        ))
        self.cacheSizeText = cacheSizeText
        box.contents = self

        title = String(localized: "Settings", bundle: .module)
        tabBarItem.image = UIImage(named: "cog")
        tabBarItem.selectedImage = UIImage(named: "cog-filled")

        themeDidChange()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        refreshCacheSize()
    }

    private func refreshCacheSize() {
        Task {
            let size = await AppDelegate.instance.calculateCacheSize()
            let measurement = Measurement(value: Double(size), unit: UnitInformationStorage.bytes)
            let formatted: String
            if size < 1_000_000 {
                formatted = measurement.converted(to: .kilobytes).formatted(
                    .measurement(width: .abbreviated, numberFormatStyle: .number.precision(.fractionLength(0)))
                )
            } else {
                formatted = measurement.converted(to: .megabytes).formatted(
                    .measurement(width: .abbreviated, numberFormatStyle: .number.precision(.fractionLength(1)))
                )
            }
            cacheSizeText.send(formatted)
        }
    }

    func emptyCache() {
        Task {
            let sizeBefore = await AppDelegate.instance.calculateCacheSize()
            await AppDelegate.instance.emptyCache()
            let sizeAfter = await AppDelegate.instance.calculateCacheSize()

            let delta = sizeBefore - sizeAfter
            let measurement = Measurement(value: Double(max(delta, 0)), unit: UnitInformationStorage.bytes)
            let formatted: String
            if delta < 1_000_000 {
                formatted = measurement.converted(to: .kilobytes).formatted(
                    .measurement(width: .abbreviated, numberFormatStyle: .number.precision(.fractionLength(0)))
                )
            } else {
                formatted = measurement.converted(to: .megabytes).formatted(
                    .measurement(width: .abbreviated, numberFormatStyle: .number.precision(.fractionLength(1)))
                )
            }
            let message = "You cleared \(formatted)! Some system-managed files can't be removed, so a small amount of cache usage is normal."
            let alertController = UIAlertController(title: "Cache Cleared", message: message, preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                self.dismiss(animated: true)
            })
            self.present(alertController, animated: true)

            refreshCacheSize()
        }
    }

    func resetSettings() {
        let alert = UIAlertController(
            title: "Reset All Settings?",
            message: "This will restore all preferences to their defaults. You will remain logged in.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Reset", style: .destructive) { _ in
            UserDefaults.standard.resetPreferences()
        })
        present(alert, animated: true)
    }

    func exportSettings() {
        do {
            let data = try SettingsExporter.exportSettings()
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let filename = "awful-settings-\(dateFormatter.string(from: Date())).json"
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
            try data.write(to: tempURL)

            let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
            activityVC.popoverPresentationController?.sourceView = view
            activityVC.completionWithItemsHandler = { _, _, _, _ in
                try? FileManager.default.removeItem(at: tempURL)
            }
            present(activityVC, animated: true)
        } catch {
            Log.error("Failed to export settings: \(error)")
            let alert = UIAlertController(title: "Export Failed", message: error.localizedDescription, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
    }

    func importSettings() {
        let types = [UTType.json]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types)
        picker.delegate = self
        picker.allowsMultipleSelection = false
        present(picker, animated: true)
    }

    func goToAwfulThread() {
        AppDelegate.instance.open(route: .threadPage(threadID: "3837546", page: .nextUnread, .seen))
    }

    override func themeDidChange() {
        super.themeDidChange()

        if theme[bool: "showRootTabBarLabel"] == false {
            tabBarItem.imageInsets = UIEdgeInsets(top: 9, left: 0, bottom: -9, right: 0)
            tabBarItem.title = nil
        } else {
            tabBarItem.imageInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
            tabBarItem.title = title
        }
    }
}

extension SettingsViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }

        guard url.startAccessingSecurityScopedResource() else {
            let alert = UIAlertController(title: "Import Failed", message: "Could not access the selected file.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        do {
            let data = try Data(contentsOf: url)
            let result = try SettingsExporter.importSettings(from: data)

            var message = "Successfully applied \(result.appliedCount) setting\(result.appliedCount == 1 ? "" : "s")."
            if result.isOlderBuild, !result.missingKeys.isEmpty {
                message += "\n\nThis file was exported from an older version of Awful (build \(result.exportBuildNumber ?? "unknown")). \(result.missingKeys.count) newer setting\(result.missingKeys.count == 1 ? " was" : "s were") not included and will use default values."
            }

            let alert = UIAlertController(
                title: "Settings Imported",
                message: message,
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        } catch {
            Log.error("Failed to import settings: \(error)")
            let alert = UIAlertController(title: "Import Failed", message: error.localizedDescription, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
    }
}

/// See the `README.md` section "Alternate App Icons" for more info. Now ordered in a 3 x 5 grid
private let appIcons: [AppIconDataSource.AppIcon] = [
    .init(accessibilityLabel: String(localized: "Rated five", bundle: .module), imageName: AppIconImageNames.rated_five),
    .init(accessibilityLabel: String(localized: "Rated five (trans flag)", bundle: .module), imageName: AppIconImageNames.rated_five_trans),
    .init(accessibilityLabel: String(localized: "Rated five (pride flag)", bundle: .module), imageName: AppIconImageNames.rated_five_pride),
    
    .init(accessibilityLabel: String(localized: "Froggo", bundle: .module), imageName: AppIconImageNames.froggo),
    .init(accessibilityLabel: String(localized: "Doggo", bundle: .module), imageName: AppIconImageNames.staredog),
    .init(accessibilityLabel: String(localized: "V", bundle: .module), imageName: AppIconImageNames.v),
    
    .init(accessibilityLabel: String(localized: "Froggo (purple)", bundle: .module), imageName: AppIconImageNames.froggo_purple),
    .init(accessibilityLabel: String(localized: "Doggo poking tongue", bundle: .module), imageName: AppIconImageNames.staredog_tongue),
    .init(accessibilityLabel: String(localized: "Ghost", bundle: .module), imageName: AppIconImageNames.ghost_blue),
    
    .init(accessibilityLabel: String(localized: "Cute", bundle: .module), imageName: AppIconImageNames.cute),
    .init(accessibilityLabel: String(localized: "Stare", bundle: .module), imageName: AppIconImageNames.stare),
    .init(accessibilityLabel: String(localized: "Five", bundle: .module), imageName: AppIconImageNames.five),
    
    .init(accessibilityLabel: String(localized: "Smith", bundle: .module), imageName: AppIconImageNames.smith),
    .init(accessibilityLabel: String(localized: "Creep", bundle: .module), imageName: AppIconImageNames.greenface),
    .init(accessibilityLabel: String(localized: "Riker", bundle: .module), imageName: AppIconImageNames.riker),
]

@MainActor private func makeAppIconDataSource() -> AppIconDataSource {
    let selectedIconName = UIApplication.shared.alternateIconName
    let selected = appIcons.first { $0.imageName == selectedIconName } ?? appIcons.first!
    return AppIconDataSource(
        appIcons: appIcons,
        imageLoader: { Image("\($0.imageName)_preview", bundle: .main) },
        selected: selected,
        setter: {
            let iconName = $0 == appIcons.first ? nil : $0.imageName
            try await UIApplication.shared.setAlternateIconName(iconName)
        }
    )
}

/// Wrapper for observing the current `User`.
struct SettingsContainerView: View {
    let appIconDataSource: AppIconDataSource
    let cacheSizeText: CurrentValueSubject<String, Never>
    @ObservedObject var currentUser: User
    let emptyCache: () -> Void
    let exportSettings: () -> Void
    let goToAwfulThread: () -> Void
    let hasRegularSizeClassInLandscape: Bool
    let importSettings: () -> Void
    let isMac: Bool
    let isPad: Bool
    let logOut: () -> Void
    let managedObjectContext: NSManagedObjectContext
    let resetSettings: () -> Void

    @State private var displayedCacheSize: String = "Calculating…"

    var body: some View {
        SettingsView(
            appIconDataSource: appIconDataSource,
            avatarURL: currentUser.avatarURL,
            cacheSizeText: displayedCacheSize,
            canOpenURL: UIApplication.shared.canOpenURL(_:),
            currentUsername: currentUser.username ?? "",
            emptyCache: emptyCache,
            exportSettings: exportSettings,
            goToAwfulThread: goToAwfulThread,
            hasRegularSizeClassInLandscape: hasRegularSizeClassInLandscape,
            importSettings: importSettings,
            isMac: isMac,
            isPad: isPad,
            logOut: logOut,
            resetSettings: resetSettings
        )
        .environment(\.managedObjectContext, managedObjectContext)
        .themed()
        .onReceive(cacheSizeText) { newValue in
            displayedCacheSize = newValue
        }
    }
}

extension SettingsViewController: RestorableLocation {
    var restorationRoute: AwfulRoute? {
        .settings
    }
}
