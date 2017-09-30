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
    
    override func awakeFromNib() {
        super.awakeFromNib()

        collection.dataSource = self
        collection.delegate = self
        collection.register(UINib(nibName: "AppIconCell", bundle: nil), forCellWithReuseIdentifier: "AppIcon")
        
        if #available(iOS 10.3, *) {
            selectedIconName = UIApplication.shared.alternateIconName ?? "Bars"
        } else {
            selectedIconName = "Bars"
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 2
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let collection = collection else {
            Log.e("No collection in view")
            return UICollectionViewCell()
        }
        
        let cell = collection.dequeueReusableCell(withReuseIdentifier: "AppIcon", for: indexPath) as! AppIconCell
        if indexPath.row == 0 {
            cell.iconName = "Bars"
        } else {
            cell.iconName = "v"
        }
        
        return cell
    }
    
    static var iconDidChangeNotification: String {
        return "AwfulPostsViewExternalStylesheetDidUpdate"
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let cell = collectionView.cellForItem(at: indexPath) as! AppIconCell
        print("Selected \(cell.iconName)")
        selectedIconName = cell.iconName

        if #available(iOS 10.3, *) {
            if (selectedIconName == "Bars") {
                UIApplication.shared.setAlternateIconName(nil, completionHandler: nil)
            } else {
                UIApplication.shared.setAlternateIconName(selectedIconName, completionHandler: nil)
            }
            
            NotificationCenter.default.post(name: NSNotification.Name(rawValue:AppIconPickerCell.iconDidChangeNotification), object: nil)
        } else {
            let unsupportedAlert = UIAlertController(title: "Unsupported Feature", message: "Changing app icons isn't supported in iOS before 10.3. We really should hide this whole setting!")
            unsupportedAlert.present(self.nearestViewController!, animated: true, completion: nil)
        }
    }
}
