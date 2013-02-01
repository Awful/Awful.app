//
//  AwfulParsing+Lepers.m
//  Awful
//
//  Created by me on 1/29/13.
//  Copyright (c) 2013 Regular Berry Software LLC. All rights reserved.
//

#import "XPathQuery.h"
#import "AwfulParsing+Lepers.h"
#import "TFHpple.h"

@interface LepersParsedInfo ()

@property (nonatomic) AwfulLeperType banType;
@property (copy, nonatomic) NSString *postID;
@property (nonatomic) NSDate *banDate;
@property (copy, nonatomic) NSString *bannedUserID;
@property (copy, nonatomic) NSString *bannedUserName;
@property (copy, nonatomic) NSString *banReason;
@property (copy, nonatomic) NSString *modUserID;
@property (copy, nonatomic) NSString *modUserName;
@property (copy, nonatomic) NSString *adminUserID;
@property (copy, nonatomic) NSString *adminUserName;

@end


@implementation LepersParsedInfo

+ (NSArray*)lepersWithHTMLData:(NSData *)htmlData {
    NSMutableArray *assholes = [NSMutableArray new];
    NSArray *rawAssholes = PerformRawHTMLXPathQuery(htmlData, @"//table.standard.full//tbody//tr");
    for (NSString *ass in rawAssholes) {
        NSData *dataForOneLeper = [ass dataUsingEncoding:NSUTF8StringEncoding];
        ThreadParsedInfo *info = [[self alloc] initWithHTMLData:dataForOneLeper];
        [assholes addObject:info];
    }
    return assholes;
}

- (void)parseHTMLData
{
    //columns are:
    //ban type, date, user, reason, requested, approved
    TFHpple *doc = [[TFHpple alloc] initWithHTMLData:self.htmlData];
    
    NSArray *tds = [doc search:@"//td"];
    
    if (tds.count == 6)
    {
        TFHppleElement *a = [tds[LeperTableColumnType] childrenWithTagName:@"a"][0];
        self.postID = a.attributes[@"href"];
        self.banType = BanTypeFromString(a.content);
        
        self.banDate = PostDateFromString([tds[LeperTableColumnDate] content]);
    
        a = [tds[LeperTableColumnJerk] childrenWithTagName:@"a"][0];
        self.bannedUserID = UserIDFromURLString(a.attributes[@"href"]);
        self.bannedUserName = a.content;
        
        self.banReason = [tds[LeperTableColumnReason] content];
        
        a = [tds[LeperTableColumnMod] childrenWithTagName:@"a"][0];
        self.modUserID = UserIDFromURLString(a.attributes[@"href"]);
        self.modUserName = a.content;
        
        a = [tds[LeperTableColumnAdmin] childrenWithTagName:@"a"][0];
        self.adminUserID = UserIDFromURLString(a.attributes[@"href"]);
        self.adminUserName = a.content;
    }
}

- (NSString*)banID
{
    //bans don't have an id.  not a visible one anyway.
    //so we'll just make our own
    //looks like they get approved in batches so there's a lot of identical dates
    //i think "bantype.userid.date" should be unique
    
    return [NSString stringWithFormat:@"%@.%@.%f", @"bantype", self.bannedUserID, self.banDate.timeIntervalSince1970];
}

@end

AwfulLeperType BanTypeFromString(NSString* s)
{
    if ([s isEqualToString:@"PROBATION"])
        return AwfulLeperTypeProbation;
    
    if ([s isEqualToString:@"BAN"])
        return AwfulLeperTypeBan;
    
    if ([s isEqualToString:@"PERMABAN"])
        return AwfulLeperTypePermaban;
    
    return AwfulLeperTypeUnknown;
}
