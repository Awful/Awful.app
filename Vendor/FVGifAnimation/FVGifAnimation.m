//
//  FVGifAnimation.m
//  FutaView
//
//  Created by flexfrank on 12/06/20.
//  Copyright (c) 2012年 flexfrank.net. All rights reserved.
//

#import "FVGifAnimation.h"
#import <ImageIO/ImageIO.h>
static NSUInteger gcdInteger(NSUInteger a,NSUInteger b){
    if(a>=b){
        if(b==0){
            return b;
        }
        NSUInteger rem=a%b;
        if(rem==0){
            return b;
        }else{
            return gcdInteger(b,rem);
        }
    }else{
        return gcdInteger(b,a);
    }
}

@implementation FVGifAnimation
+ (BOOL)canAnimateImageSource:(CGImageSourceRef)imgSrc{
    if(imgSrc==NULL) return false;
    CFStringRef type= CGImageSourceGetType(imgSrc);
    if([(__bridge NSString*)type isEqual:@"com.compuserve.gif"]){
        return CGImageSourceGetCount(imgSrc)>1;
    }
    return false;
    
}

+ (BOOL)canAnimateImageData:(NSData*)data{
    if(data){
        CGImageSourceRef imgSrc= CGImageSourceCreateWithData((__bridge CFDataRef)data, NULL);
        if(imgSrc==NULL) return false;
        BOOL result=[self canAnimateImageSource:imgSrc];
        CFRelease(imgSrc);
        return result;
    }
    return false;
}
+ (BOOL)canAnimateImageURL:(NSURL*)url{
    if(url){
        CGImageSourceRef imgSrc= CGImageSourceCreateWithURL((__bridge CFURLRef)url, NULL);
        if(imgSrc==NULL) return false;
        BOOL result=[self canAnimateImageSource:imgSrc];
        CFRelease(imgSrc);
        return result;
    }
    return false;
}

- (NSArray*)delaysForImageSource:(CGImageSourceRef)iSrc{
    size_t imageCount=CGImageSourceGetCount(iSrc);
    NSMutableArray* delays=[NSMutableArray array];
    for(size_t i=0;i<imageCount;i++){
        CFDictionaryRef propI= CGImageSourceCopyPropertiesAtIndex(iSrc, i, NULL);
        double delay=0.1;
        if(propI){
            CFDictionaryRef gifProp=CFDictionaryGetValue(propI, kCGImagePropertyGIFDictionary);
            if(gifProp){
                CFNumberRef delayVal=CFDictionaryGetValue(gifProp, kCGImagePropertyGIFDelayTime);
                delay=[(__bridge NSNumber*)delayVal doubleValue];
            }
            CFRelease(propI);
        }
        [delays addObject:[NSNumber numberWithDouble:delay]];
    }
    return [NSArray arrayWithArray:delays];
}

- (double)totalDurationForDelays:(NSArray*)delays{
    double result=0.0;
    for(NSNumber* num in delays){
        result+=[num doubleValue];
    }
    return result;    
}

- (NSUInteger)gcdInNumbers:(NSIndexSet*)set{
    NSMutableIndexSet* delays=[set mutableCopy];
    if([delays count]==0 ){return 0;}
    while([delays count]>1){
        NSUInteger twoDelays[2];
        [delays getIndexes:twoDelays maxCount:2 inIndexRange:nil];
        [delays removeIndex:twoDelays[0]];
        [delays removeIndex:twoDelays[1]];
        NSUInteger m= gcdInteger(twoDelays[0],twoDelays[1]);
        [delays addIndex:m];
    }
    return [delays firstIndex];
}

-(NSUInteger)timesliceForDelays:(NSArray*)delays{
    NSMutableIndexSet* delaySet=[NSMutableIndexSet indexSet];
    for(NSNumber* num in delays){
        [delaySet addIndex:round([num doubleValue]*100.0)];
    }
    return [self gcdInNumbers:delaySet];
}

- (NSArray*)animationImagesForImageSource:(CGImageSourceRef)iSrc withDelays:(NSArray*)delays{
    NSMutableArray* animationImages=[NSMutableArray array];
    NSUInteger timeslice=[self timesliceForDelays:delays];
    size_t images_count=CGImageSourceGetCount(iSrc);
    for(size_t i=0;i<images_count;i++){
        CGImageRef image=CGImageSourceCreateImageAtIndex(iSrc, i, NULL);
        if(image){
            UIImage* uiimage=[[UIImage alloc] initWithCGImage:image];
            NSUInteger times=round([[delays objectAtIndex:i] doubleValue]*100)/timeslice;
            for(NSUInteger j=0;j<times;j++){
                [animationImages addObject:uiimage];
            }
            CGImageRelease(image);
        }
    }
    return [NSArray arrayWithArray:animationImages];
}

- (void)loadImagesFromImageSource:(CGImageSourceRef)imgSrc{
    if(imgSrc && [[self class] canAnimateImageSource:imgSrc]){
        CFStringRef type= CGImageSourceGetType(imgSrc);
        if([(__bridge NSString*)type isEqual:@"com.compuserve.gif"]){
            NSInteger loopCount=0;
            CFDictionaryRef prop=CGImageSourceCopyProperties(imgSrc, NULL);
            CFDictionaryRef gifProp=CFDictionaryGetValue(prop, kCGImagePropertyGIFDictionary);
            if(gifProp){
                CFNumberRef loopNum=CFDictionaryGetValue(gifProp, kCGImagePropertyGIFLoopCount);
                loopCount=[(__bridge NSNumber*)loopNum integerValue];
            }
            CFRelease(prop);
            NSArray* delays=[self delaysForImageSource:imgSrc];
            self->duration=[self totalDurationForDelays:delays];
            self->images=[self animationImagesForImageSource:imgSrc withDelays:delays];
            self->loops=loopCount;
        }
    }
}
- (id)initWithData:(NSData*)data{
    self=[self init];
    if(self){
        CGImageSourceRef imgSrc= CGImageSourceCreateWithData((__bridge CFDataRef)data, NULL);
        if(imgSrc){
            [self loadImagesFromImageSource:imgSrc];
            CFRelease(imgSrc);
        }
    }
    return self;
}
- (id)initWithURL:(NSURL*)url{
    self=[self init];
    if(self){
        CGImageSourceRef imgSrc= CGImageSourceCreateWithURL((__bridge CFURLRef)url, NULL);
        if(imgSrc){
            [self loadImagesFromImageSource:imgSrc];
            CFRelease(imgSrc);
        }
    }
    return self;
}

- (void)setAnimationToImageView:(UIImageView*)imageView{
    if(self->images!=nil){
        imageView.animationImages=self->images;
        imageView.animationDuration=self->duration;
        imageView.animationRepeatCount=self->loops;
    }
}

- (BOOL) canAnimate{
    return self->images!=nil;
}
@end