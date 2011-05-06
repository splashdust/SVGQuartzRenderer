//
//  SVGRendererTouchAppDelegate.h
//  SVGRendererTouch
//
//  Created by Aaron Boxer on 10-10-15.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SVGRenderViewTouch.h"

@interface SVGRendererTouchAppDelegate : NSObject <UIApplicationDelegate, SVGRenderViewTouchDelegate> {
    UIWindow *window;
    NSOperationQueue *queue;
    SVGRenderViewTouch* svgView;
    
}

@property (nonatomic, retain) IBOutlet UIWindow *window;
@property (retain) SVGRenderViewTouch* svgView;

@end

