//  AppIconPickerCell.swift
//
//  Copyright 2017 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

private let Log = Logger.get()

final class AppIconPickerCell: UITableViewCell, UICollectionViewDataSource, UICollectionViewDelegate {

    @IBOutlet var collectionView: UICollectionView?
    var selectedIconName: String?

    private let appIcons: [AppIcon] = findAppIcons()
    
    override func awakeFromNib() {
        super.awakeFromNib()

        collectionView?.dataSource = self
        collectionView?.delegate = self
        collectionView?.register(UINib(nibName: "AppIconCell", bundle: Bundle(for: AppIconPickerCell.self)), forCellWithReuseIdentifier: "AppIcon")
        
        if #available(iOS 10.3, *) {
            selectedIconName = UIApplication.shared.alternateIconName ?? appIcons.first?.iconName
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return appIcons.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let appIcon = appIcons[indexPath.item]
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "AppIcon", for: indexPath) as! AppIconCell

        cell.configure(
            imageName: appIcon.filename,
            isCurrentlySelectedIcon: selectedIconName == appIcon.iconName)

        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let appIcon = appIcons[indexPath.item]
        Log.d("Selected \(appIcon.iconName ?? "") at \(indexPath)")

        let previousSelection = selectedIconName
        selectedIconName = appIcon.iconName

        guard #available(iOS 10.3, *) else { return }

        UIApplication.shared.setAlternateIconName(appIcon.iconName, completionHandler: { error in
            if let error = error {
                Log.e("could not set alternate app icon: \(error)")
            }
            else {
                Log.i("changed app icon to \(appIcon.iconName ?? "")")
            }
        })

        let oldSelectedIndexPath = appIcons
            .firstIndex { $0.iconName == previousSelection }
            .map { IndexPath(item: $0, section: 0) }
        let reloadIndexPaths = [indexPath, oldSelectedIndexPath].compactMap { $0 }
        collectionView.reloadItems(at: reloadIndexPaths)
    }
}

private struct AppIcon: Equatable {
    let filename: String

    var iconName: String? {
        let scanner = Scanner(string: filename)
        guard
            scanner.scan("AppIcon-"),
            let iconName = scanner.scanUpTo("-")
            else { return nil }
        return iconName
    }
}

private func findAppIcons() -> [AppIcon] {
    guard let icons = Bundle(for: AppIconPickerCell.self).object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any] else {
        Log.e("could not find CFBundleIcons in Info.plist")
        return []
    }

    guard let primary = icons["CFBundlePrimaryIcon"] as? [String: Any] else {
        Log.e("could not find CFBundlePrimaryIcon in Info.plist")
        return []
    }

    func filenameContainsHandySize(_ filename: String) -> Bool {
        return filename.contains("60x60")
    }

    guard
        let primaryFilenames = primary["CFBundleIconFiles"] as? [String],
        let primaryFilename = primaryFilenames.first(where: filenameContainsHandySize) else
    {
        Log.e("could not find primary CFBundleIconFiles in Info.plist")
        return []
    }

    let alternates = icons["CFBundleAlternateIcons"] as? [String: Any] ?? [:]
    let alternateFilenames = alternates.values
        .compactMap { $0 as? [String: Any] }
        .compactMap { $0["CFBundleIconFiles"] as? [String] }
        .compactMap { $0.first(where: filenameContainsHandySize) }
        .sorted()

    let filenames = [primaryFilename] + alternateFilenames
    return filenames.map { AppIcon(filename: $0) }
}
