//
//  AwfulHelpController.h
//  Awful
//
//  Created by Regular Berry on 6/28/11.
//  Copyright 2011 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface AwfulHelpBox : UIView {
    UILabel *_title;
    UILabel *_answer;
}

@property (nonatomic, retain) IBOutlet UILabel *title;
@property (nonatomic, retain) IBOutlet UILabel *answer;

@end

@interface AwfulQA : NSObject {
    NSString *_question;
    NSString *_answer;
}

@property (nonatomic, retain) NSString *question;
@property (nonatomic, retain) NSString *answer;

-(id)initWithQuestion : (NSString *)question answer : (NSString *)answer;
+(id)withQuestion : (NSString *)question answer : (NSString *)answer;

@end

@interface AwfulHelpController : UIViewController {
    AwfulHelpBox *_helpBox;
    AwfulHelpBox *_firstBox;
    UIScrollView *_scroller;
    NSMutableArray *_content;
    NSMutableArray *_helpBoxes;
}

@property (nonatomic, retain) IBOutlet AwfulHelpBox *helpBox;
@property (nonatomic, retain) IBOutlet AwfulHelpBox *firstBox;
@property (nonatomic, retain) IBOutlet UIScrollView *scroller;
@property (nonatomic, retain) NSMutableArray *content;
@property (nonatomic, retain) NSMutableArray *helpBoxes;

@end
