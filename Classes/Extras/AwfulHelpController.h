//
//  AwfulHelpController.h
//  Awful
//
//  Created by Regular Berry on 6/28/11.
//  Copyright 2011 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface AwfulHelpBox : UIView

@property (nonatomic, strong) IBOutlet UILabel *title;
@property (nonatomic, strong) IBOutlet UILabel *answer;

@end

@interface AwfulQA : NSObject

@property (nonatomic, strong) NSString *question;
@property (nonatomic, strong) NSString *answer;

-(id)initWithQuestion : (NSString *)question answer : (NSString *)answer;
+(id)withQuestion : (NSString *)question answer : (NSString *)answer;

@end

@interface AwfulHelpController : UIViewController

@property (nonatomic, strong) IBOutlet AwfulHelpBox *helpBox;
@property (nonatomic, strong) IBOutlet AwfulHelpBox *firstBox;
@property (nonatomic, strong) IBOutlet UIScrollView *scroller;
@property (nonatomic, strong) NSMutableArray *content;
@property (nonatomic, strong) NSMutableArray *helpBoxes;

@end
