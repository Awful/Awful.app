//  CacheHeaderCalculations.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "CacheHeaderCalculations.h"

void SetCacheHeadersForRequest(NSMutableURLRequest *request, NSHTTPURLResponse *response)
{
    NSDictionary *headers = [response allHeaderFields];
    
    if (headers[@"Etag"]) {
        [request setValue:headers[@"Etag"] forHTTPHeaderField:@"If-None-Match"];
    }
    
    if (headers[@"Last-Modified"]) {
        [request setValue:headers[@"Last-Modified"] forHTTPHeaderField:@"If-Modified-Since"];
    }
}
