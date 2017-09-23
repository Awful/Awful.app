//
//  AwfulIconCellTableViewCell.swift
//  Awful
//
//  Created by Liam Westby on 9/23/17.
//  Copyright © 2017 Awful Contributors. All rights reserved.
//

import UIKit

class IconTableViewCell: UITableViewCell, UICollectionViewDataSource {
    @IBOutlet weak var collection: UICollectionView?
    
    override func awakeFromNib() {
        collection?.dataSource = self
        collection?.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "appIcon")
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 20
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collection?.dequeueReusableCell(withReuseIdentifier: "appIcon", for: indexPath)
        cell!.contentView.addSubview(UIImageView(image: UIImage(named: "AppIcon-v-60x60", in: Bundle(for: type(of: self)), compatibleWith: nil)))
        return cell!
    }
}
