//
//  AwfulYOSPOSThreadCell.m
//  Awful
//
//  Created by me on 5/17/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulCustomForumYOSPOS.h"
#import "AwfulThread.h"

@implementation AwfulYOSPOSThreadCell

-(void) layoutSubviews {
    [super layoutSubviews];
    
    self.backgroundColor =  AwfulYOSPOSThreadCell.backgroundColor;
    self.contentView.backgroundColor = AwfulYOSPOSThreadCell.backgroundColor;
}

-(void)configureForThread:(AwfulThread *)thread {
    [super configureForThread:thread];
    
    //remove rounded corners on badge
    self.badgeColor = [UIColor blackColor];
    self.badge.backgroundColor = [UIColor YOSPOSGreenColor];
    self.badge.layer.borderWidth = 1;
    self.badge.layer.borderColor = [[UIColor YOSPOSGreenColor] CGColor];
    self.badge.badgeFont = [UIFont fontWithName:@"Courier" size:11];
    self.badge.radius = 1;
    
    //display badge number in hex
    if (self.badgeString)
        self.badgeString = [NSString stringWithFormat:@"%X", self.badgeString.intValue];
    
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    
    //green tinted thread rating
    if (self.ratingImage.image)
        self.ratingImage.image = self.ratingImage.image.greenVersion;
    
}

-(void) configureTagImage {
    //green thread tags
    [super configureTagImage];
    
    if (self.imageView.image) {
        self.imageView.image = [self.imageView.image greenVersion];
    }
    else {
        self.tagLabel.backgroundColor = [UIColor blackColor];
        self.tagLabel.textColor = [UIColor YOSPOSGreenColor];
    }
}

-(void) setSelected:(BOOL)selected animated:(BOOL)animated{
    //make selected cells flash like a cursor
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
    //swap in the custom activity view
    AwfulThread *thread = notification.object;
    if (thread.threadID.intValue != self.thread.threadID.intValue) return;
    
    AwfulYOSPOSActivityIndicatorView *activity = [AwfulYOSPOSActivityIndicatorView new];
    self.accessoryView = activity;
    [activity startAnimating];

}

//custom color and font definitions
+(UIColor*) textColor { return [UIColor YOSPOSGreenColor]; }
+(UIColor*) backgroundColor { return [UIColor blackColor]; }
+(UIFont*) textLabelFont { return [UIFont fontWithName:@"Courier" size:14]; }
+(UIFont*) detailLabelFont { return [UIFont fontWithName:@"Courier" size:10]; }

@end


@implementation AwfulYOSPOSThreadListController
//that's not enough, let's do the threadlist too

-(void) viewDidLoad {
    [super viewDidLoad];
    self.tableView.separatorColor = [UIColor YOSPOSGreenColor];
    
    //change navbar title and formatting
    UILabel *title = [UILabel new];
    title.font = [UIFont fontWithName:@"Courier-Bold" size:22];
    title.textAlignment = UITextAlignmentCenter;
    title.adjustsFontSizeToFitWidth = YES;
    title.textColor = [UIColor YOSPOSGreenColor];
    title.backgroundColor = [UIColor blackColor];
    title.frame = CGRectMake(0, 0, 200, 50);
    title.text = self.forum.name;
    self.navigationItem.titleView = title;


}

-(UIBarButtonItem*) customBackButton {
    //override this method for custom back button
    
    //here we're making one flat, rectangular, and green/black
    UIButton *back = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 70, 26)];
    [back setTitle:@"cd .." forState:(UIControlStateNormal)];
    [back setTitleColor:[UIColor YOSPOSGreenColor] forState:UIControlStateNormal];
    back.titleLabel.textAlignment = UITextAlignmentCenter;
    back.titleLabel.font = [UIFont fontWithName:@"Courier-Bold" size:12];
    back.layer.borderColor = [[UIColor YOSPOSGreenColor] CGColor];
    back.layer.borderWidth = 1;
    
    //when using uibarbuttonitem initwithcustomview, the target and action properties get ignored
    //so the custom view needs to have them
    [back addTarget:self action:@selector(pop) forControlEvents:(UIControlEventTouchUpInside)];
    
    UIBarButtonItem *button = [[UIBarButtonItem alloc] initWithCustomView:back];
    return button;
}

-(UIImage*) customNavigationBarBackgroundImageForMetrics:(UIBarMetrics)metrics {
    //change the navbar background
    //it ignores backgroundColor and tintColor, I assume because it's originally set with an image
    //so it needs to be replaced with an image
    //this just returns a black image
    return [UIImage blackNavigationBarImageForMetrics:metrics];
}

-(AwfulRefreshControl*) awfulRefreshControl {
    //override this method for a custom Pull to Refresh control
    if (!_awfulRefreshControl) {
        _awfulRefreshControl = [[AwfulYOSPOSRefreshControl alloc] initWithFrame:CGRectMake(0, -50, self.tableView.fsW, 50)];
    }
    return _awfulRefreshControl;
}

-(NSString*) tableView:(UITableView *)tableView titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath {
    //custom string for deleting a table cell, which marks a thread unread
    return @"rm -rf";
}
@end

@implementation AwfulYOSPOSRefreshControl
@synthesize activityView = _activityView;
//this custom refresh control just changes the colors and fonts,
//and changes the activity spinner

-(id) initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    self.title.font = [UIFont fontWithName:@"Courier" size:16];
    self.title.textColor = [UIColor blackColor];
    
    self.subtitle.textColor = [UIColor blackColor];
    self.subtitle.font = [UIFont fontWithName:@"Courier" size:12];
    
    [[self.layer.sublayers objectAtIndex:0] removeFromSuperlayer];
    self.backgroundColor = [UIColor YOSPOSGreenColor];
    
    return self;
}

-(UIActivityIndicatorView*) activityView {
    if (!_activityView) {
        _activityView = [[AwfulYOSPOSActivityIndicatorView alloc] initWithInvertedColors];
        [self addSubview:_activityView];
    }
    return _activityView;
}

@end

@implementation AwfulYOSPOSActivityIndicatorView
//change the activity indicator to something more yosposish
//an ascii spinner using | \ -- /
-(id) init {
    self = [super init];
    
    _lbl = [UILabel new];
    _lbl.tag = 0;
    _lbl.font = [UIFont fontWithName:@"Courier" size:16];
    _lbl.textColor = [UIColor YOSPOSGreenColor];
    _lbl.backgroundColor = [UIColor blackColor];
    
    _lbl.text = @"--";
    _lbl.tag = 0;
    _lbl.textAlignment = UITextAlignmentCenter;
    [_lbl sizeToFit];
    self.frame = _lbl.frame;
    [self addSubview:_lbl];

    return self;
}

-(id) initWithInvertedColors {
    self = [self init];
    _lbl.textColor = [UIColor blackColor];
    _lbl.backgroundColor = [UIColor YOSPOSGreenColor];
    return self;
}

-(void) startAnimating {
    self.hidden = NO;
     _timer = [NSTimer scheduledTimerWithTimeInterval:.219/2
                                               target:self 
                                             selector:@selector(activityTimer) 
                                             userInfo:nil 
                                              repeats:YES
               ];
}

-(void) activityTimer {
    _lbl.tag++;
    switch (_lbl.tag%4) {
        case 0:
            _lbl.text = @"--";
            return;
            
        case 1:
            _lbl.text = @"\\";
            return;
        case 2:
            _lbl.text = @"\u00A6";  //broken pipe unicode
            return;
        case 3:
            _lbl.text = @"/";
            return;
            
            
        default:
            break;
    }
}

-(void) stopAnimating {
    self.hidden = YES;
    [_timer invalidate];
    _timer = nil;
}

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

+(UIImage *)blackNavigationBarImageForMetrics:(UIBarMetrics)metrics
{
    CGFloat height = metrics == UIBarMetricsDefault ? 42 : 32;
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(1, height), YES, 0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGColorSpaceRef rgb = CGColorSpaceCreateDeviceRGB();
    CGContextSetFillColorSpace(context, rgb);
    
    // 1px top border, below status bar.
    CGContextSaveGState(context);
    CGContextMoveToPoint(context, 0, 0);
    CGContextAddRect(context, CGRectMake(0, 0, 1, height));
    CGContextSetFillColorWithColor(context, [[UIColor blackColor] CGColor]);
    CGContextFillPath(context);
    CGContextRestoreGState(context);
    
    CGColorSpaceRelease(rgb);
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return [image resizableImageWithCapInsets:UIEdgeInsetsMake(height, 0, 0, 0)];
}

@end


