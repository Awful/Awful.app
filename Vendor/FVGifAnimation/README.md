FVGifAnimation
==============

FVGifAnimation is a library to play an animated GIF on iOS.
FVGifAnimation loads frames of an animed GIF using Image I/O
and sets frames to UIImageView.

FVGifAnimation requires iOS 4 or later.

Usage
-----
```objective-c
    FVGifAnimation* gifAnimation=[[[FVGifAnimation alloc] initWithData:data] autorelease];
    if([gifAnimation canAnimate]){
        [gifAnimation setAnimationToImageView:self.imageView];
        [self.imageView startAnimating];
    }

```

License
-------
FVGifAnimation is licensed under the MIT License.
Copyright &copy; 2012, Shumpei Akai.
