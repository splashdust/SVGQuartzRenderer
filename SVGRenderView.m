//
//  SVGRenderView.m
//  SVGRender
//
//  Created by Joacim Magnusson on 2010-09-22.
//  Copyright 2010 Joacim Magnusson. All rights reserved.
//

#import "SVGRenderView.h"

@implementation SVGRenderView

CGImageRef svgDrawing;
BOOL hasRendered;

SVGQuartzRenderer *svgRenderer;
CGContextRef viewContext;

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        svgRenderer = [[SVGQuartzRenderer alloc] init];
		[svgRenderer setDelegate:self];
		[svgRenderer drawSVGFile:@"/Users/joacim/Desktop/skull.svg"];
    }
    return self;
}

- (void)awakeFromNib
{
}

- (void)drawRect:(NSRect)dirtyRect {
	
	viewContext = (CGContextRef)[[NSGraphicsContext currentContext] graphicsPort];
	CGContextDrawImage(viewContext, [self frame], svgDrawing);

}

- (CGContextRef)svgRenderer:(id)renderer
				requestedCGContextWidthSize:(CGSize)size
{
	[self setFrame:NSMakeRect(0, 0, size.width, size.height)];
	
	CGContextRef ctx = [renderer createBitmapContext];
	
	return ctx;
}

- (void)svgRenderer:(id)renderer
		didFinnishRenderingFile:(NSString *)file
		inCGContext:(CGContextRef)context
{
	NSLog(@"Finnished we are!");
	svgDrawing = CGBitmapContextCreateImage(context);
}


- (BOOL)isFlipped {return YES;}

-(void)dealloc
{
	[svgRenderer release];
	[super dealloc];
}

@end
