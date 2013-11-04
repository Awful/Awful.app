//  AwfulKeyboardBar.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulKeyboardBar.h"

@interface AwfulKeyboardButton : UIButton

@property (readonly, copy, nonatomic) NSString *character;

- (instancetype)initWithCharacter:(NSString *)character;

@end


@interface AwfulKeyboardBar ()

@property (weak, nonatomic) CAGradientLayer *gradient;

@end


@implementation AwfulKeyboardBar

- (void)setCharacters:(NSArray *)characters
{
    if ([_characters isEqualToArray:characters]) return;
    _characters = [characters copy];
    [self.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    for (NSString *character in characters) {
        AwfulKeyboardButton *button = [[AwfulKeyboardButton alloc] initWithCharacter:character];
        [button addTarget:self action:@selector(keyPressed:)
         forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:button];
    }
    [self setNeedsLayout];
}

- (void)keyPressed:(AwfulKeyboardButton *)button
{
    [[UIDevice currentDevice] playInputClick];
    [self.keyInputView insertText:button.character];
}

#pragma mark - UIView

- (id)initWithFrame:(CGRect)frame
{
    if (!(self = [super initWithFrame:frame])) return nil;
	self.backgroundColor = [UIColor colorWithRed:0.863 green:0.871 blue:0.886 alpha:1];
    self.opaque = YES;
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    return self;
}

- (void)layoutSubviews
{
    self.gradient.frame = (CGRect){ .size = self.bounds.size };
    const CGFloat width = UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ? 60 : 44;
    const CGFloat between = UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ? 10 : 5;
    CGFloat x = floorf((CGRectGetWidth(self.bounds) -
                        (width * [self.characters count]) -
                        (between * ([self.characters count] - 1)))
                       / 2);
    for (NSUInteger i = 0; i < [self.characters count]; i++) {
        [self.subviews[i] setFrame:CGRectMake(x, 2, width, CGRectGetHeight(self.bounds) - 4)];
        x += width + between;
    }
}

#pragma mark - UIInputViewAudioFeedback

- (BOOL)enableInputClicksWhenVisible
{
    return YES;
}

@end


@implementation AwfulKeyboardButton
{
    NSString *_character;
}

- (id)initWithCharacter:(NSString *)character
{
    if (!(self = [super init])) return nil;
    _character = [character copy];
    [self setTitle:_character forState:UIControlStateNormal];
		[self setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    
    self.titleLabel.font = [UIFont systemFontOfSize:22];
    
		self.backgroundColor = [UIColor colorWithRed:0.992 green:0.992 blue:0.996 alpha:1];
		self.layer.cornerRadius = 3.5;
    self.layer.borderWidth = 0;
    return self;
}

@end
