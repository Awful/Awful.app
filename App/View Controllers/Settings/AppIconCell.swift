//  AppIconCell.swift
//
//  Copyright 2017 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

final class AppIconCell: UICollectionViewCell {

    @IBOutlet private var imageView: UIImageView!
    @IBOutlet private var isSelectedIcon: UIImageView!

    private var loadingImageName: String?

    override func awakeFromNib() {
        super.awakeFromNib()

        imageView.layer.mask = makeSquircleMask()
    }

    func configure(imageName: String?, isCurrentlySelectedIcon: Bool) {
        isSelectedIcon.isHidden = !isCurrentlySelectedIcon

        guard let imageName = imageName else {
            loadingImageName = nil
            imageView.image = nil
            return
        }

        guard loadingImageName != imageName else { return }

        imageView.image = nil
        loadingImageName = imageName
        Task { [weak self] in
            let image = await Task.detached {
                UIImage(named: imageName)?.makeDecompressedCopy()
            }.value
            if let self, self.loadingImageName == imageName {
                self.imageView.image = image
            }
        }
    }
}

private func makeSquircleMask() -> CALayer {
    let shape = CAShapeLayer()
    shape.path = UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: 60, height: 60), cornerRadius: 13).cgPath
    shape.fillColor = UIColor.black.cgColor
    return shape
}
