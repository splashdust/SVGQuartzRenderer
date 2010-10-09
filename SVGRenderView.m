/*--------------------------------------------------
* Copyright (c) 2010 Joacim Magnusson
* 
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
* 
* The above copyright notice and this permission notice shall be included in
* all copies or substantial portions of the Software.
* 
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
* AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
* OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
* THE SOFTWARE.
*--------------------------------------------------*/

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
