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
		[self setMultipleTouchEnabled:YES];
	
        svgRenderer = [[SVGQuartzRenderer alloc] init];
		[svgRenderer setDelegate:self];
		origin = frame.origin;
		initialDistance = -1;
		svgDrawing = NULL;
		initialScale = -1;
		firstRender = YES;
		
		
    }
    return self;
}

-(void) open:(NSString*)path{
	
	self.filePath = path;
	[svgRenderer drawSVGFile:path];
}



- (void)drawRect:(CGRect)dirtyRect {
	
	viewContext = UIGraphicsGetCurrentContext();
	
	//fill dirty rect with black
	CGFloat black[4] = {0, 0, 0, 1};
	CGContextSetFillColor(viewContext, black);
	CGContextFillRect(viewContext, dirtyRect);
	
	//draw image
	CGContextDrawImage(viewContext, CGRectMake(origin.x, 
											   origin.y, 
											   svgRenderer.documentSize.width, 
											   svgRenderer.documentSize.height), svgDrawing);

}



- (CGContextRef)svgRenderer:(id)renderer
				requestedCGContextWithSize:(CGSize)size
{	
	//initialize scale to fit window
	if (firstRender) {
		float scale = (float)self.frame.size.width/svgRenderer.documentSize.width;
		[svgRenderer setScale:scale];
		firstRender = NO;
	}
	CGContextRef ctx = [renderer createBitmapContext];
	
	return ctx;
}

- (void)svgRenderer:(id)renderer
		didFinnishRenderingFile:(NSString *)file
		inCGContext:(CGContextRef)context
{
	NSLog(@"Finnished we are!");
	CGImageRelease(svgDrawing);
	svgDrawing = CGBitmapContextCreateImage(context);
}


- (CGFloat)distanceBetweenTwoPoints:(CGPoint)fromPoint toPoint:(CGPoint)toPoint {
	
	float x = toPoint.x - fromPoint.x;
    float y = toPoint.y - fromPoint.y;
    
    return sqrt(x * x + y * y);
}

-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
	UITouch *touch = [touches anyObject];
	NSUInteger tapCount = [touch tapCount];
	if (tapCount == 2)
	{
		origin = CGPointMake(0,0);
		float scale = (float)self.frame.size.width/(svgRenderer.documentSize.width/svgRenderer.scale);
		[svgRenderer setScale:scale];
		[self open:filePath];
		[self setNeedsDisplay];	
	    initialScale = -1;
		panning = NO;
		return;
	}
	
	NSSet* allTouches =  [event allTouches];
	switch ([allTouches count]) {
        case 1:
			panning = NO;
			if ( (svgRenderer.documentSize.width > self.frame.size.width+1) || (svgRenderer.documentSize.height > self.frame.size.height+1)  ) { 
				initialPoint = 	[[[allTouches allObjects] objectAtIndex:0] locationInView:self];
				panning = YES;
			}
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
			
			initialScale = svgRenderer.scale;				

            break;
        }
			
    }
	[super touchesBegan:touches withEvent:event];
}

-(void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event;
{
	
	NSSet* allTouches =  [event allTouches];
	switch ([allTouches count])
	{
        case 1:
			if (panning)
		    {
			CGPoint newPoint = 	[[[allTouches allObjects] objectAtIndex:0] locationInView:self];
			origin.x += newPoint.x - initialPoint.x;
			origin.y += newPoint.y - initialPoint.y;
			initialPoint = newPoint;
			[self setNeedsDisplay];

			}
			break;
        default:

			// in a pinch gesture, we scale the image
			if (initialDistance > 0)
			{
				UITouch *touch1 = [[allTouches allObjects] objectAtIndex:0];
				UITouch *touch2 = [[allTouches allObjects] objectAtIndex:1];
				
				CGPoint point1 = [touch1 locationInView:self];
				CGPoint point2 = [touch2 locationInView:self];
				
				CGFloat currentDistance = [self distanceBetweenTwoPoints:point1
																 toPoint:point2];
				
				float oldScale = svgRenderer.scale;
				svgRenderer.scale = initialScale * currentDistance/initialDistance;
				
				//fix point in middle of two touches during zoom 
				CGPoint middle;
				middle.x = (point1.x + point2.x)/2;
				middle.y = (point1.y + point2.y)/2;
				
				float factor = svgRenderer.scale/oldScale;
				
				origin.x = (1-factor)*middle.x + factor*origin.x;
				origin.y = (1-factor)*middle.y + factor*origin.y;
				
				[self setNeedsDisplay];				
				
			}			
           
            break;
	}
				
	
	[super touchesMoved:touches withEvent:event];	
		
   	
}

-(void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event 
{
	NSSet* allTouches =  [event allTouches];
	switch ([allTouches count])
	{
        case 1:
            panning = NO;
			break;
        default:
			if (initialDistance > 0)
			{
				[self open:filePath];
				[self setNeedsDisplay];							
				
			}
			initialDistance = -1;			
            break;
	}
	
	[super touchesEnded:touches withEvent:event];


}

//location is (x,y) coordinate of point in unscaled image
-(void) locate:(CGPoint)location withZoom:(float)zoom
{
	//assume frame.origin = (0,0)
	//location*zoom + offset = frame.center
	float x = self.frame.size.width - location.x*zoom;
	float y = self.frame.size.height - location.y*zoom;
	origin = CGPointMake(x,y);
	[svgRenderer setScale:zoom];
	[self open:filePath];
	[self setNeedsDisplay];	
	
}


-(void)dealloc
{
	[svgRenderer release];
	CGImageRelease(svgDrawing);
	[super dealloc];
}

@end
