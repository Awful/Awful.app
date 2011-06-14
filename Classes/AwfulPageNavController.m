//
//  AwfulPageNavController.m
//  Awful
//
//  Created by Sean Berry on 11/26/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulPageNavController.h"
#import "AwfulNavController.h"
#import "AwfulPageCount.h"

@implementation AwfulPageNavController

@synthesize cancelButton, pageLabel, picker;
@synthesize goButton;

-(id)initWithAwfulPage : (AwfulPage *)in_page
{
    self = [super initWithNibName:@"PageNumber" bundle:[NSBundle mainBundle]];
    if(self) {
        page = in_page;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    UIImage *button_back = [UIImage imageNamed:@"btn_template_bg.png"];
    UIImage *stretch_back = [button_back stretchableImageWithLeftCapWidth:17 topCapHeight:17];
    [cancelButton setBackgroundImage:stretch_back forState:UIControlStateNormal];
    [goButton setBackgroundImage:stretch_back forState:UIControlStateNormal];
    
    [picker reloadAllComponents];
    if(page != nil) {
        [picker selectRow:page.pages.currentPage-1 inComponent:0 animated:NO];
        pageLabel.text = [NSString stringWithFormat:@"Current Page: %d", page.pages.currentPage];
    }
}

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView
{
    return 1;
}

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component
{
    if(page != nil) {
        return page.pages.totalPages;
    }
    return 0;
}

- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component
{
    return [NSString stringWithFormat:@"%d", row+1];
}

// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations.
    return YES;
}

-(IBAction)go
{
    int chosen_page = [picker selectedRowInComponent:0] + 1;
    if(page != nil) {
        AwfulPage *req_page = [[AwfulPage alloc] initWithAwfulThread:page.thread startAt:THREAD_POS_SPECIFIC pageNum:chosen_page];
        AwfulNavController *nav = getnav();
        [nav loadPage:req_page];
        [req_page release];
        [nav hidePageNav];
    }
}

-(IBAction)cancel
{
    AwfulNavController *nav = getnav();
    [nav hidePageNav];
}

@end
