//
//  UIView+Lazy.m
//  Awful
//
//  Created by me on 4/13/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "UIView+Lazy.h"

@implementation UIView (Lazy)

-(CGFloat) foX {
    return self.frame.origin.x;
}

-(void) setFoX:(CGFloat)foX {
    CGRect frame = self.frame;
    frame.origin.x = foX;
    self.frame = frame;
}


-(CGFloat) foY {
    return self.frame.origin.y;
}

-(void) setFoY:(CGFloat)foY {
    CGRect frame = self.frame;
    frame.origin.y = foY;
    self.frame = frame;
}


-(CGFloat) fsH {
    return self.frame.size.height;
}

-(void) setFsH:(CGFloat)fsH {
    CGRect frame = self.frame;
    frame.size.height = fsH;
    self.frame = frame;
}


-(CGFloat) fsW {
    return self.frame.size.width;
}

-(void) setFsW:(CGFloat)fsW {
    CGRect frame = self.frame;
    frame.size.width = fsW;
    self.frame = frame;
}
@end
