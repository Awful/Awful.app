//  UITableView+HideStuff.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "UITableView+HideStuff.h"

@implementation UITableView (HideStuff)

- (void)awful_unstickSectionHeaders
{
    CGRect headerFrame = CGRectMake(0, 0, 0, self.sectionHeaderHeight * 2);
    self.tableHeaderView = [[UIView alloc] initWithFrame:headerFrame];
    UIEdgeInsets contentInset = self.contentInset;
    contentInset.top -= CGRectGetHeight(headerFrame);
    self.contentInset = contentInset;
}

- (void)awful_hideExtraneousSeparators
{
    self.tableFooterView = [UIView new];
}

@end
