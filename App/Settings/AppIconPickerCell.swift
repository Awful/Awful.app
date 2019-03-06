//  AppIconPickerCell.swift
//
//  Copyright 2017 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

private let Log = Logger.get()

final class AppIconPickerCell: UITableViewCell, UICollectionViewDataSource, UICollectionViewDelegate {
    @IBOutlet weak var collection: UICollectionView!
    var selectedIconName: String?

    private let appIcons: [AppIcon] = findAppIcons()
    
    override func awakeFromNib() {
        super.awakeFromNib()

        collection.dataSource = self
        collection.delegate = self
        collection.register(UINib(nibName: "AppIconCell", bundle: nil), forCellWithReuseIdentifier: "AppIcon")
        
        if #available(iOS 10.3, *) {
            selectedIconName = UIApplication.shared.alternateIconName ?? appIcons.first?.iconName
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return appIcons.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let collection = collection else {
            Log.e("No collection in view")
            return UICollectionViewCell()
        }
        let appIcon = appIcons[indexPath.item]
        
        let cell = collection.dequeueReusableCell(withReuseIdentifier: "AppIcon", for: indexPath) as! AppIconCell

        cell.configure(image: UIImage(named: appIcon.filename), isCurrentlySelectedIcon: selectedIconName == appIcon.iconName)

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
            .index { $0.iconName == previousSelection }
            .map { IndexPath(item: $0, section: 0) }
        let reloadIndexPaths = [indexPath, oldSelectedIndexPath].compactMap { $0 }
        collectionView.reloadItems(at: reloadIndexPaths)
    }
}

private struct AppIcon: Equatable {
    let filename: String

    static func == (lhs: AppIcon, rhs: AppIcon) -> Bool {
        return lhs.filename == rhs.filename
    }

    var iconName: String? {
        let scanner = Scanner(string: filename)
        guard scanner.scanString("AppIcon-", into: nil) else {
            return nil
        }
        var iconName: NSString?
        guard scanner.scanUpTo("-", into: &iconName) else {
            return nil
        }
        return (iconName as String?) ?? ""
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
        .compactMap { (value: Any) -> [String: Any]? in value as? [String: Any] }
        .compactMap { (dict: [String: Any]) -> [String]? in dict["CFBundleIconFiles"] as? [String] }
        .compactMap { (files: [String]) -> String? in files.first(where: filenameContainsHandySize) }
        .sorted { (lhs: String, rhs: String) -> Bool in lhs.caseInsensitiveCompare(rhs) == .orderedAscending }

    var filenames = [primaryFilename]
    filenames.append(contentsOf: alternateFilenames)
    return filenames.map { (filename: String) -> AppIcon in AppIcon(filename: filename) }
}
