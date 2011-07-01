//
//  SmilieGrabber.m
//  Awful
//
//  Created by Sean Berry on 8/5/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//
/*
#import "SmilieGrabber.h"
#import "AwfulAppDelegate.h"
#import "AwfulUtil.h"
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"

@implementation Smilie

@synthesize text, src, type, filename;

@end


@implementation SmilieGrabber

-(id)init
{
    smilies = [[NSMutableArray alloc] init];
    
    return self;
}

-(void)dealloc
{
    [smilies release];
    [super dealloc];
}

-(void)updateSmilieList
{
    NSLog(@"loading smilie page...");
    AwfulAppDelegate *del = (AwfulAppDelegate *)[[UIApplication sharedApplication] delegate];
    [del loadDataFromURL:@"misc.php?action=showsmilies" caller:self selWhenDone:@selector(parseSmilies:)];
}

-(void)parseSmilies : (NSMutableData *)sm_data
{
    NSLog(@"got it... parsing smilies...");
    TFHpple *page_data = [[TFHpple alloc] initWithHTMLData:sm_data];
    NSArray *smilie_html = [page_data rawSearch:@"//li[@class='smilie']"];
    for(NSString *html in smilie_html) {
        TFHpple *sm = [[TFHpple alloc] initWithHTMLData:[html dataUsingEncoding:NSUTF8StringEncoding]];
        TFHppleElement *text = [sm searchForSingle:@"//div[@class='text']"];
        TFHppleElement *img = [sm searchForSingle:@"//img"];
        if(text != nil && img != nil) {
            Smilie *s = [[Smilie alloc] init];
            s.text = [text content];
            s.src = [img objectForKey:@"src"];
            
            NSURL *u = [[NSURL alloc] initWithString:s.src];
            s.type = [u pathExtension];
            s.filename = [u lastPathComponent];
            [u release];
            
            [smilies addObject:s];
            [s release];
        }
        [sm release];
    }
    [page_data release];
    NSLog(@"%d smilies found", [smilies count]);
    [self grabNextSmilie];
}

-(void)grabNextSmilie
{
    if([smilies count] > 0) {
        Smilie *s = [smilies objectAtIndex:0];
        NSLog(@"grabbing %@", s.filename);
        AwfulAppDelegate *del = (AwfulAppDelegate *)[[UIApplication sharedApplication] delegate];
        [del loadDataFromURL:s.src caller:self selWhenDone:@selector(saveSmilie:) hasPrefix:YES];
    }
}

-(void)saveSmilie : (NSMutableData *)data
{   
    if([smilies count] == 0) {
        return;
    }
    
    Smilie *s = [smilies objectAtIndex:0];
    NSLog(@"saving %@", s.filename);
    [s retain];
    [smilies removeObjectAtIndex:0];
    
    NSString *path = [[AwfulUtil getDocsDir] stringByAppendingPathComponent:s.filename];
    BOOL wrote = [data writeToFile:path atomically:YES];
    if(wrote) {
        NSLog(@"successfully wrote %@\n", s.filename);
    } else {
        NSLog(@"failed to write %@\n", s.filename);
    }
    
    NSString *db_path = [[NSBundle mainBundle] pathForResource:@"forums" ofType:@"sqlite"];
    FMDatabase *db = [[FMDatabase alloc] initWithPath:db_path];
    [db open];
    [db executeUpdate:@"INSERT INTO smilies (text, filename, type) VALUES (?, ?, ?)", s.text, s.filename, s.type];
    if([db hadError]) {
        NSLog(@"failed to update db %@", [db lastErrorMessage]);
    }
    [db close];
    [db release];
    [s release];
    
    [self grabNextSmilie];
}

@end*/
