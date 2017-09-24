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
    var selectedIconName: String = "v"
    
    override func awakeFromNib() {
        collection?.dataSource = self
        collection?.register(UINib(nibName: "AwfulIcon", bundle: nil), forCellWithReuseIdentifier: "appIcon")
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
}
