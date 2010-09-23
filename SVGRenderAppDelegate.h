//
//  SVGRenderAppDelegate.h
//  SVGRender
//
//  Created by Joacim Magnusson on 2010-09-22.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface SVGRenderAppDelegate : NSObject <NSApplicationDelegate> {
    NSWindow *window;
}

@property (assign) IBOutlet NSWindow *window;

@end
