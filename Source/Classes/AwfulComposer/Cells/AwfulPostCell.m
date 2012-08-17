//
//  AwfulPostCell.m
//  Awful
//
//  Created by me on 7/30/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulPostCell.h"

@implementation AwfulPostCell
@synthesize dictionary = _dictionary;
@synthesize draft = _draft;

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.textLabel.font = [UIFont systemFontOfSize:16];
        self.textLabel.textColor = [UIColor darkGrayColor];
        self.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    return self;
}

-(void) didSelectCell:(UIViewController *)viewController {
    
}

-(void) setDictionary:(NSDictionary *)dictionary {
    _dictionary = dictionary;
    self.textLabel.text = [dictionary objectForKey:AwfulPostCellTextKey];
    self.detailTextLabel.text = [dictionary objectForKey:AwfulPostCellDetailKey];
}

-(void) setDraft:(AwfulDraft *)draft {
    _draft = draft;
    if (self.dictionary && [self.dictionary objectForKey:AwfulPostCellDraftInputKey]) {
        [draft addObserver:self
                forKeyPath:[self.dictionary objectForKey:AwfulPostCellDraftInputKey]
                   options:(NSKeyValueObservingOptionNew) context:nil
         ];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    //override me
}
@end
