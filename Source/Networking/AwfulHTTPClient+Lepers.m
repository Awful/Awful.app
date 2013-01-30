//
//  AwfulHTTPClient+Lepers.m
//  Awful
//
//  Created by me on 1/29/13.
//  Copyright (c) 2013 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulHTTPClient+Lepers.h"
#import "AwfulParsing+Lepers.h"
#import "AwfulParsing.h"

@implementation AwfulHTTPClient (Lepers)

- (NSOperation *)listBansOnPage:(NSInteger)page
                        andThen:(void (^)(NSError *error, NSArray *threads))callback
{
    NSDictionary *parameters = @{ @"pagenumber": @(page) };
    NSURLRequest *request = [self requestWithMethod:@"GET"
                                               path:@"banlist.php"
                                         parameters:parameters];
    AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:request
                                                               success:^(id _, id data)
                                  {
                                      dispatch_async(self.parseQueue, ^{
                                          NSArray *infos = [LepersParsedInfo lepersWithHTMLData:data];
                                          dispatch_async(dispatch_get_main_queue(), ^{
                                              NSArray *bans = [AwfulLeper lepersCreatedOrUpdatedWithParsedInfo:infos];
                                              if (callback) callback(nil, bans);
                                          });
                                      });
                                  } failure:^(id _, NSError *error) {
                                      if (callback) callback(error, nil);
                                  }];
    [self enqueueHTTPRequestOperation:op];
    return op;
}

@end
