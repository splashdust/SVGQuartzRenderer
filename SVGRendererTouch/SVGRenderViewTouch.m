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

#import "SVGRenderViewTouch.h"

@interface SVGRenderViewTouch (private)

- (CGFloat)distanceBetweenTwoPoints:(CGPoint)fromPoint toPoint:(CGPoint)toPoint;

@end

@implementation SVGRenderViewTouch

@synthesize filePath;



- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        svgRenderer = [[SVGQuartzRenderer alloc] init];
		[svgRenderer setDelegate:self];
		[svgRenderer setScale:0.5];
		origin = frame.origin;
		[self setMultipleTouchEnabled:YES];
		initialDistance = -1;
		
    }
    return self;
}

-(void) open:(NSString*)path{
	
	self.filePath = path;
	[svgRenderer drawSVGFile:path];
}



- (void)drawRect:(CGRect)dirtyRect {
	
	viewContext = UIGraphicsGetCurrentContext();
	CGContextDrawImage(viewContext, CGRectMake(origin.x, 
											   origin.y, 
											   [self frame].size.width, 
											   [self frame].size.height), svgDrawing);

}

- (CGContextRef)svgRenderer:(id)renderer
				requestedCGContextWidthSize:(CGSize)size
{
	[self setFrame:CGRectMake(0, 0, size.width, size.height)];
	
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




- (CGFloat)distanceBetweenTwoPoints:(CGPoint)fromPoint toPoint:(CGPoint)toPoint {
	
	float x = toPoint.x - fromPoint.x;
    float y = toPoint.y - fromPoint.y;
    
    return sqrt(x * x + y * y);
}

-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
	NSSet* allTouches =  [event allTouches];
	switch ([allTouches count]) {
        case 1:
			initialPoint = 	[[[allTouches allObjects] objectAtIndex:0] locationInView:self];
			[super touchesBegan:touches withEvent:event];
			break;
			
        default:
        {
            // handle multi touch
            UITouch *touch1 = [[allTouches allObjects] objectAtIndex:0];
            UITouch *touch2 = [[allTouches allObjects] objectAtIndex:1];
            initialDistance = [self distanceBetweenTwoPoints:[touch1 locationInView:self]
                                                     toPoint:[touch2 locationInView:self]];
			if (initialDistance == 0)
				initialDistance = -1;
            break;
        }
			
    }
}

-(void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event;
{
	
	NSSet* allTouches =  [event allTouches];
	switch ([allTouches count])
	{
        case 1:
		    {
			CGPoint newPoint = 	[[[allTouches allObjects] objectAtIndex:0] locationInView:self];
			origin.x += newPoint.x - initialPoint.x;
			origin.y += newPoint.y - initialPoint.y;
			initialPoint = newPoint;
				[self setNeedsDisplay];
			[super touchesMoved:touches withEvent:event];	
			}
			break;
        default:

			// in a pinch gesture, we scale the image
			if (initialDistance > 0)
			{
				UITouch *touch1 = [[allTouches allObjects] objectAtIndex:0];
				UITouch *touch2 = [[allTouches allObjects] objectAtIndex:1];
				CGFloat currentDistance = [self distanceBetweenTwoPoints:[touch1 locationInView:self]
																 toPoint:[touch2 locationInView:self]];
				CGFloat zoom = currentDistance/initialDistance;
				zoom = MIN(zoom,4);
				zoom = MAX(0.5,zoom);
				svgRenderer.scale = zoom;
				[self open:filePath];				
				
				
			}			
           
            break;
	}
		
   	
}

-(void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event 
{
	NSSet* allTouches =  [event allTouches];

	if ([allTouches count] == 1) {
		[super touchesEnded:touches withEvent:event];
		return;
	}
	
	initialDistance = -1;
}



-(void)dealloc
{
	[svgRenderer release];
	[super dealloc];
}

@end
