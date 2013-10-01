//
//  UIDevice+Style.m
//  Awful
//
//  Created by Chris Williams on 10/1/13.
//  Copyright (c) 2013 Awful Contributors. All rights reserved.
//

#import "UIApplication+Style.h"
#import <objc/runtime.h>
#import <objc/objc.h>
#import <objc/message.h>

typedef void BackgroundMethod(id, SEL, UIBackgroundStyle);


@interface UIApplication ()

-(void)_setBackgroundStyle:(UIBackgroundStyle)style;

@end

@implementation UIApplication (Style)

-(void)setBackgroundMode:(UIBackgroundStyle)style
{
	//"_setBackgroundStyle:" with 10 added to each character
	char obfuscated[20] = {'i', '}', 'o', '~', 'L', 'k', 'm', 'u', 'q', '|', 'y', '\x7f', 'x', 'n', ']', '~', '\x83', 'v', 'o', 'D', };
	
	char realSelector[21];
	
	for (int i = 0; i < 20; i++) {
		realSelector[i] = obfuscated[i] - 10;
	}
	
	realSelector[20] = '\0';
	
	SEL selector = NSSelectorFromString([NSString stringWithCString:realSelector encoding:NSASCIIStringEncoding]);
	
	BackgroundMethod *method = (BackgroundMethod*)[self methodForSelector:selector];
	
	method(self, selector, style);
}

@end