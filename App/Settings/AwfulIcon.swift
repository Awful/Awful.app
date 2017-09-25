//
//  AwfulIcon.swift
//  Awful
//
//  Created by Liam Westby on 9/24/17.
//  Copyright © 2017 Awful Contributors. All rights reserved.
//

import UIKit

class AwfulIcon: UICollectionViewCell {
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        NotificationCenter.default.addObserver(self, selector: #selector(AwfulIcon.settingsDidChange(_:)), name: NSNotification.Name.AwfulSettingsDidChange, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @IBOutlet weak var imageView: UIImageView!
    var iconName: String = "" {
        didSet {
            imageView.image = UIImage(named: "AppIcon-\(iconName)-60x60", in: Bundle(for: type(of: self)), compatibleWith: nil)
            imageView.layer.cornerRadius = 10.0
            imageView.clipsToBounds = true
            updateSelectionHighlight()
        }
    }
    
    func isCurrentIcon() -> Bool {
        if #available(iOS 10.3, *) {
            return UIApplication.shared.alternateIconName ?? "Bars" == iconName
        }
        
        // Always get the bars if the version is too old
        return iconName == "Bars"
        
    }
    
    func updateSelectionHighlight() {
        if isCurrentIcon() {
            print("Icon \(iconName) is current icon")
            imageView.layer.borderWidth = 6
            imageView.layer.borderColor = (Theme.currentTheme["tintColor"]! as UIColor).cgColor
        } else {
            print("Icon \(iconName) is not current icon")
            imageView.layer.borderWidth = 0
        }
    }
    
    @objc fileprivate func settingsDidChange(_ notification: Notification) {
        print("Setting did change")
        let userInfo = (notification).userInfo!
        let changeKey = userInfo[AwfulSettingsDidChangeSettingKey]! as! String
        print(changeKey)
        if changeKey == AwfulSettingsKeys.appIconName.takeUnretainedValue() as String {
            print("Updating selection highlight")
            updateSelectionHighlight()
        }
    }
}
