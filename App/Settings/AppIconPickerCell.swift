//
//  AppIconPickerCell.swift
//  Awful
//
//  Created by Liam Westby on 9/23/17.
//  Copyright © 2017 Awful Contributors. All rights reserved.
//

import UIKit

private let Log = Logger.get(level: .debug)

final class AppIconPickerCell: UITableViewCell, UICollectionViewDataSource, UICollectionViewDelegate {
    @IBOutlet weak var collection: UICollectionView!
    var selectedIconName: String?

    private let iconNames: [String] = findIconNames()
    
    override func awakeFromNib() {
        super.awakeFromNib()

        collection.dataSource = self
        collection.delegate = self
        collection.register(UINib(nibName: "AppIconCell", bundle: nil), forCellWithReuseIdentifier: "AppIcon")
        
        if #available(iOS 10.3, *) {
            selectedIconName = UIApplication.shared.alternateIconName ?? iconNames.first ?? ""
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return iconNames.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let collection = collection else {
            Log.e("No collection in view")
            return UICollectionViewCell()
        }
        let iconName = iconNames[indexPath.item]
        
        let cell = collection.dequeueReusableCell(withReuseIdentifier: "AppIcon", for: indexPath) as! AppIconCell

        cell.configure(image: UIImage(named: "AppIcon-\(iconName)-60x60"), isCurrentlySelectedIcon: selectedIconName == iconName)

        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let iconName = iconNames[indexPath.item]
        Log.d("Selected \(iconName) at \(indexPath)")

        let previousSelection = selectedIconName
        selectedIconName = iconName

        guard #available(iOS 10.3, *) else { return }

        let newSelectedIndex = iconNames.index(of: iconName)
        let alternateIconName = newSelectedIndex == iconNames.startIndex ? nil : iconName
        UIApplication.shared.setAlternateIconName(alternateIconName, completionHandler: { error in
            if let error = error {
                Log.e("could not set alternate app icon: \(error)")
            }
            else {
                Log.i("changed app icon to \(iconName)")
            }
        })

        let oldSelectedIndex = previousSelection.flatMap(iconNames.index)
        let reloadIndexPaths = [newSelectedIndex, oldSelectedIndex]
            .flatMap { $0 }
            .map { IndexPath(item: $0, section: 0) }
        collectionView.reloadItems(at: reloadIndexPaths)
    }
}

private func findIconNames() -> [String] {
    guard let icons = Bundle(for: AppIconPickerCell.self).object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any] else {
        Log.e("could not find CFBundleIcons in Info.plist")
        return []
    }

    guard let primary = icons["CFBundlePrimaryIcon"] as? [String: Any] else {
        Log.e("could not find CFBundlePrimaryIcon in Info.plist")
        return []
    }

    guard
        let primaryFilenames = primary["CFBundleIconFiles"] as? [String],
        let primaryFilename = primaryFilenames.first else
    {
        Log.e("could not find primary CFBundleIconFiles in Info.plist")
        return []
    }
    let primaryName: String = {
        let scanner = Scanner(string: primaryFilename)
        scanner.scanString("AppIcon-", into: nil)
        var name: NSString?
        guard scanner.scanUpTo("-", into: &name) else {
            return ""
        }
        return (name ?? "") as String
    }()

    let alternates = icons["CFBundleAlternateIcons"] as? [String: Any] ?? [:]
    let alternateNames = Array(alternates.keys)

    return [primaryName] + alternateNames.sorted { $0.caseInsensitiveCompare($1) == .orderedAscending }
}
