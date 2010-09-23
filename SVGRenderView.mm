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

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        
    }
    return self;
}

- (void)drawRect:(NSRect)dirtyRect {
    
	SVGQuartzRenderer *renderer = [[SVGQuartzRenderer alloc] init];
	NSImage *rendered = [renderer imageFromSVGFile:@"/drawing.svg" view:(NSView *)self];
	
	//[self setFrame:NSMakeRect(0, 0, rendered.size.width, rendered.size.height)];
	
	//[rendered drawInRect:NSMakeRect( 0, 0, previewSize.width, previewSize.height )
	//			 fromRect:NSMakeRect( 0, 0, [origImage size].width, [origImage size].height )
	//			operation:NSCompositeSourceOver
	//			 fraction:1.0];
	
}

@end
