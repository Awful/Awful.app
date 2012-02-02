//
//  AwfulUserInfoRequest.h
//  Awful
//
//  Created by Sean Berry on 11/21/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import "ASIHTTPRequest.h"
#import "AwfulUser.h"

@interface AwfulUserNameRequest : ASIHTTPRequest {
    AwfulUser *_user;
}

@property (nonatomic, strong) AwfulUser *user;

-(id)initWithAwfulUser : (AwfulUser *)user;

@end

@interface AwfulUserSettingsRequest : AwfulUserNameRequest {
}

@end