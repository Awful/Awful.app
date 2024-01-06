//  FLAnimatedImageView+Nuke.swift
//
//  Copyright 2019 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import FLAnimatedImage
import NukeExtensions

extension FLAnimatedImageView {
    open override func nuke_display(
        image: UIImage?,
        data: Data?
    ) {
        self.image = image

        guard let image = image, let data = data else {
            animatedImage = nil
            return
        }

        Task {
            let animated = await Task.detached {
                FLAnimatedImage(animatedGIFData: data)
            }.value
            if self.image === image {
                self.animatedImage = animated
            }
        }
    }
}
