//  FLAnimatedImageView+Nuke.swift
//
//  Copyright 2019 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import FLAnimatedImage
import Nuke

extension FLAnimatedImageView {
    open override func nuke_display(image: PlatformImage?) {
        self.image = image

        guard let image = image, let data = image.animatedImageData else {
            animatedImage = nil
            return
        }

        DispatchQueue.global()
            .async(.promise) { FLAnimatedImage(animatedGIFData: data) }
            .done {
                if self.image === image {
                    self.animatedImage = $0
                }
        }
    }
}
