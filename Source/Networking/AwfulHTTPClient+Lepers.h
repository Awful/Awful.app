//
//  AwfulHTTPClient+Lepers.h
//  Awful
//
//  Created by me on 1/29/13.
//  Copyright (c) 2013 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulHTTPClient.h"

@interface AwfulHTTPClient (Lepers)
- (NSOperation *)listBansOnPage:(NSInteger)page
                        andThen:(void (^)(NSError *error, NSArray *bans))callback;
@end
