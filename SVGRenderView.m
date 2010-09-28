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
		[svgRenderer setScale:1.0];
    }
    return self;
}

- (IBAction)openFile:(id)sender
{	
	NSOpenPanel *chooseDirPanel = [NSOpenPanel openPanel];
	[chooseDirPanel setTitle:@"Open SVG file"];
	[chooseDirPanel setPrompt:@"Open"];
	[chooseDirPanel setAllowedFileTypes:[NSArray arrayWithObject:@"SVG"]];
	[chooseDirPanel setCanChooseDirectories:NO];
	[chooseDirPanel setCanCreateDirectories:YES];
	
	int selected = [chooseDirPanel runModal];
	
	if(selected == NSOKButton) {
		
		[svgRenderer drawSVGFile:[chooseDirPanel filename]];
		
	} else if(selected == NSCancelButton) {
		// Cancel
		return;
	} else {
		return;
	}
}

- (void)awakeFromNib
{
}

- (void)drawRect:(NSRect)dirtyRect {
	
	viewContext = (CGContextRef)[[NSGraphicsContext currentContext] graphicsPort];
	CGContextDrawImage(viewContext, CGRectMake([self frame].origin.x, 
											   [self frame].origin.y, 
											   [self frame].size.width, 
											   [self frame].size.height), svgDrawing);

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
