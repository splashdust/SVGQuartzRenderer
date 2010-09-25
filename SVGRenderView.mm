//
//  SVGRenderView.m
//  SVGRender
//
//  Created by Joacim Magnusson on 2010-09-22.
//  Copyright 2010 Joacim Magnusson. All rights reserved.
//

#import "SVGRenderView.h"
#import "SVGQuartzRenderer.h"

@implementation SVGRenderView

SVGQuartzRenderer *renderer;

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        renderer = [[SVGQuartzRenderer alloc] init];
		[self setFrame:NSMakeRect(0, 0, 2000, 2000)];
    }
    return self;
}

- (void)drawRect:(NSRect)dirtyRect {
    
	CGContextRef myContext = (CGContext *)[[NSGraphicsContext currentContext] graphicsPort];
	[renderer drawSVGFile:@"/tiger.svg" inCGContext:myContext];
	
	//[self setFrame:NSMakeRect(0, 0, rendered.size.width, rendered.size.height)];
	
	//[rendered drawInRect:NSMakeRect( 0, 0, previewSize.width, previewSize.height )
	//			 fromRect:NSMakeRect( 0, 0, [origImage size].width, [origImage size].height )
	//			operation:NSCompositeSourceOver
	//			 fraction:1.0];

}

- (BOOL)isFlipped {return YES;}

-(void)dealloc
{
	[renderer release];
	[super dealloc];
}

@end
