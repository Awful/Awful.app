//
//  AwfulIconCellTableViewCell.swift
//  Awful
//
//  Created by Liam Westby on 9/23/17.
//  Copyright © 2017 Awful Contributors. All rights reserved.
//

import UIKit

class AwfulIconCollection: UITableViewCell, UICollectionViewDataSource, UICollectionViewDelegate {
    @IBOutlet weak var collection: UICollectionView?
    open var selectedIconName: String?
    
    override func awakeFromNib() {
        collection?.dataSource = self
        collection?.delegate = self
        collection?.register(UINib(nibName: "AwfulIcon", bundle: nil), forCellWithReuseIdentifier: "appIcon")
        
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
        guard let collection = collection else { Logger.get().e("No collection in view"); return UICollectionViewCell() }
        
        let cell = collection.dequeueReusableCell(withReuseIdentifier: "appIcon", for: indexPath) as! AwfulIcon
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
        let cell = collectionView.cellForItem(at: indexPath) as! AwfulIcon
        print("Selected \(cell.iconName)")
        selectedIconName = cell.iconName

        if #available(iOS 10.3, *) {
            if (selectedIconName == "Bars") {
                UIApplication.shared.setAlternateIconName(nil, completionHandler: nil)
            } else {
                UIApplication.shared.setAlternateIconName(selectedIconName, completionHandler: nil)
            }
            
            NotificationCenter.default.post(name: NSNotification.Name(rawValue:AwfulIconCollection.iconDidChangeNotification), object: nil)
        } else {
            let unsupportedAlert = UIAlertController(title: "Unsupported Feature", message: "Changing app icons isn't supported in iOS before 10.3. We really should hide this whole setting!")
            unsupportedAlert.present(self.nearestViewController!, animated: true, completion: nil)
        }
    }
}
