//
//  AwfulYOSPOSThreadCell.m
//  Awful
//
//  Created by me on 5/17/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulYOSPOSThreadCell.h"
#import "AwfulThread.h"

@interface AwfulYOSPOSThreadCell ()
@property (nonatomic,strong) NSTimer* timer;
@end

@implementation AwfulYOSPOSThreadCell
@synthesize timer = _timer;

-(void) layoutSubviews {
    [super layoutSubviews];
    
    self.backgroundColor =  AwfulYOSPOSThreadCell.backgroundColor;
    self.contentView.backgroundColor = AwfulYOSPOSThreadCell.backgroundColor;
}

-(void)configureForThread:(AwfulThread *)thread {
    [super configureForThread:thread];
    
    UIColor *textColor = [UIColor YOSPOSGreenColor];
    UIColor *bgColor = [UIColor blackColor];
    
    self.backgroundColor =  bgColor;
    self.contentView.backgroundColor = bgColor;
    
    self.textLabel.textColor = textColor;
    self.textLabel.font = [UIFont fontWithName:@"Courier" size:14];
    self.textLabel.backgroundColor = [UIColor clearColor];
    
    self.detailTextLabel.textColor = textColor;
    self.detailTextLabel.font = [UIFont fontWithName:@"Courier" size:10];
    self.detailTextLabel.backgroundColor = [UIColor clearColor];
    
    self.badgeColor = [UIColor blackColor];
    self.badge.backgroundColor = [UIColor YOSPOSGreenColor];
    self.badge.layer.borderWidth = 1;
    self.badge.layer.borderColor = [[UIColor YOSPOSGreenColor] CGColor];
    self.badge.badgeFont = [UIFont fontWithName:@"Courier" size:11];
    self.badge.radius = 1;
    
    //badge number to hex
    if (self.badgeString)
        self.badgeString = [NSString stringWithFormat:@"0x%X", self.badgeString.intValue];
    
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    
    if (self.ratingImage.image)
        self.ratingImage.image = self.ratingImage.image.greenVersion;
    
}

-(void) configureTagImage {
    [super configureTagImage];
    
    if (self.tagImage.image) {
        self.tagImage.image = [self.tagImage.image greenVersion];
    }
    else {
        self.tagLabel.backgroundColor = [UIColor blackColor];
        self.tagLabel.textColor = [UIColor YOSPOSGreenColor];
    }
}

-(void) setSelected:(BOOL)selected animated:(BOOL)animated{    
    if (selected) {
        [UIView animateWithDuration:.5
                              delay:0
                            options:(UIViewAnimationOptionAutoreverse|
                                     UIViewAnimationOptionRepeat|
                                     UIViewAnimationOptionCurveEaseInOut) 
                         animations:^{
                             self.contentView.backgroundColor = [UIColor YOSPOSGreenColor];
                         } 
                         completion:^(BOOL finished) {
                             
                         }
         ];
    }
    
    else
        self.contentView.backgroundColor = [UIColor blackColor];
    
    
}
-(void) willLoadThreadPage:(NSNotification*)notification {
    AwfulThread *thread = notification.object;
    if (thread.threadID.intValue != self.thread.threadID.intValue) return;
    
    UILabel *lbl = [UILabel new];
    lbl.font = [UIFont fontWithName:@"Courier" size:16];
    lbl.textColor = [UIColor YOSPOSGreenColor];
    lbl.backgroundColor = [UIColor blackColor];
    
    lbl.text = @"--";
    lbl.tag = 0;
    lbl.textAlignment = UITextAlignmentCenter;
    [lbl sizeToFit];
    self.accessoryView = lbl;
    self.badge.hidden = YES;
    
    self.timer = [NSTimer scheduledTimerWithTimeInterval:.219/2   
                                                  target:self 
                                                selector:@selector(activityTimer) 
                                                userInfo:nil 
                                                 repeats:YES
                             ];
}


-(void) didLoadThreadPage:(NSNotification*)notification {
    [super didLoadThreadPage:notification];
    [self.timer invalidate];
    self.timer = nil;
}

-(void) activityTimer {
    UILabel *lbl = (UILabel*)self.accessoryView;
    lbl.tag++;
    switch (lbl.tag % 4) {
        case 0:
            lbl.text = @"--";
            return;
            
        case 1:
            lbl.text = @"\\";
            return;
        case 2:
            lbl.text = @"\u00A6";
            return;
        case 3:
            lbl.text = @"/";
            return;
            
            
        default:
            break;
    }
}

+(UIColor*) textColor { return [UIColor YOSPOSGreenColor]; }
+(UIColor*) backgroundColor { return [UIColor blackColor]; }
+(UIFont*) textLabelFont { return [UIFont fontWithName:@"Courier" size:14]; }
+(UIFont*) detailLabelFont { return [UIFont fontWithName:@"Courier" size:10]; }


@end


@implementation UIColor (YOSPOS)
+(UIColor*) YOSPOSGreenColor {
    return [UIColor colorWithRed:.224 green:1 blue:.224 alpha:1];
}

+(UIColor*) YOSPOSAmberColor {
    return [UIColor colorWithRed:.92 green:.81 blue:.3 alpha:1];
}
@end

@implementation UIImage (YOSPOS)

- (UIImage *) grayscaleVersion
{
    // Create image rectangle with current image width/height
    CGRect imageRect = CGRectMake(0, 0, self.size.width, self.size.height);
    
    // Grayscale color space
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceGray();
    
    // Create bitmap content with current image size and grayscale colorspace
    CGContextRef context = CGBitmapContextCreate(nil, self.size.width, self.size.height, 8, 0, colorSpace, kCGImageAlphaNone);
    
    // Draw image into current context, with specified rectangle
    // using previously defined context (with grayscale colorspace)
    CGContextDrawImage(context, imageRect, [self CGImage]);
    
    // Create bitmap image info from pixel data in current context
    CGImageRef imageRef = CGBitmapContextCreateImage(context);
    
    // Create a new UIImage object  
    UIImage *newImage = [UIImage imageWithCGImage:imageRef];
    
    // Release colorspace, context and bitmap information
    CGColorSpaceRelease(colorSpace);
    CGContextRelease(context);
    CFRelease(imageRef);
    
    // Return the new grayscale image
    return newImage;
}

-(UIImage*) greenVersion {
    return [self changeColor:[UIColor YOSPOSGreenColor]];
}

-(UIImage*) amberVersion {
    return [self changeColor:[UIColor YOSPOSAmberColor]];
}

-(UIImage*)changeColor:(UIColor*)color {
    CGImageRef maskImage = self.CGImage;
    CGFloat width = self.size.width;
    CGFloat height = self.size.height;
    CGRect bounds = CGRectMake(0,0,width,height);
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef bitmapContext = CGBitmapContextCreate(NULL, width, height, 8, 0, colorSpace, kCGImageAlphaPremultipliedLast);
    CGContextClipToMask(bitmapContext, bounds, maskImage);
    CGContextSetFillColorWithColor(bitmapContext, color.CGColor);    
    CGContextFillRect(bitmapContext, bounds);
    
    CGImageRef mainViewContentBitmapContext = CGBitmapContextCreateImage(bitmapContext);
    CGContextRelease(bitmapContext);
    
    UIImage *result = [UIImage imageWithCGImage:mainViewContentBitmapContext];
    return result;
}


@end


