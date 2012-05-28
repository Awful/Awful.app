//
//  ReloadingWebViewController.h
//  Awful
//
//  Created by Nolan Waite on 12-05-26.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ReloadingWebViewController : UIViewController

- (id)initWithFolderPath:(NSString *)folderPath;

@property (readonly, copy, nonatomic) NSString *folderPath;

@end
