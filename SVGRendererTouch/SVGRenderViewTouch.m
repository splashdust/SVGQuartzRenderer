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
#import <QuartzCore/QuartzCore.h>

@interface SVGRenderViewTouch (private)

- (CGFloat)distanceBetweenTwoPoints:(CGPoint)fromPoint toPoint:(CGPoint)toPoint;

@end

CGPoint middle;

@implementation SVGRenderViewTouch

@synthesize selectedLocation;



- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
		[self setMultipleTouchEnabled:YES];
	
        svgRenderer = [[SVGQuartzRenderer alloc] init];
		[svgRenderer setDelegate:self];
		svgRenderer.viewFrame = frame;
		origin = frame.origin;
		svgRenderer.offsetX = origin.x;
		svgRenderer.offsetY = origin.y;
		initialDistance = -1;
		svgDrawing = NULL;
		initialScaleX = -1;
		initialScaleY = -1;
		panning = NO;
        
        ////SPINNER///////////////////
        
        spinner = [[UIActivityIndicatorView alloc]
                   initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        spinner.frame = CGRectMake(0.0, 0.0, 40.0, 40.0);
        spinner.center = CGPointMake(frame.size.width/2, frame.size.height/2);
        
        [self addSubview: spinner];
        [spinner startAnimating];		
		
    }
    return self;
}

-(void) setDelegate:(id<SVGRenderViewTouchDelegate>)del
{
	delegate = del;	  
}

-(void) render
{
    if (spinner)
    {
        [spinner stopAnimating];
        [spinner removeFromSuperview];
        [spinner release];
        spinner = nil;
    }
    [svgRenderer redraw];
 
}

-(void) open:(NSString*)path{	
	[svgRenderer parse:path];       
}


- (CGContextRef)svgRenderer:(id)renderer
				requestedCGContextWithSize:(CGSize)size
{	
	CGContextRef ctx = [renderer createBitmapContext];
	
	return ctx;
}

- (void)svgRenderer:(id)renderer
		finishedRenderingInCGContext:(CGContextRef)context
{
	
	[svgLayer removeAllAnimations];
	[svgLayer removeFromSuperlayer];
	[svgLayer release];
    
	
    svgLayer= [[CALayer layer] retain];
    svgLayer.frame = CGRectMake(origin.x,origin.y, svgRenderer.documentSize.width, 
							svgRenderer.documentSize.height);
	[svgLayer setAffineTransform:CGAffineTransformMake(1,0,0,-1,0,0)]; 	
	svgDrawing = CGBitmapContextCreateImage(context);
    svgLayer.contents = (id)svgDrawing;
	CGImageRelease(svgDrawing);
    svgDrawing = NULL;
    [self.layer addSublayer:svgLayer];



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
	NSSet* allTouches =  [event allTouches];
	int touchCount = [allTouches count];
	
	switch (touchCount) {
        case 1:
		{
			CGPoint pt = [[[allTouches allObjects] objectAtIndex:0] locationInView:self];
			panning = NO;	
			if (tapCount == 2)
			{
				CGPoint relativeImagePoint = [svgRenderer scaledImagePointFromViewPoint:pt];
				if (relativeImagePoint.x <= 1 && relativeImagePoint.y <= 1 && relativeImagePoint.x >= 0 && relativeImagePoint.y >= 0)
				{
					
					//use selectedLocation, and call delegate method
					if (delegate)
						[delegate doubleTap:selectedLocation];
					
					
				} else {					
					origin = self.frame.origin;
					svgRenderer.offsetX = self.frame.origin.x;
					svgRenderer.offsetY = self.frame.origin.y;
					[svgRenderer resetScale];
					
                    [svgRenderer redraw];
					initialScaleX = -1;
					initialScaleY = -1;

				}				
				
			} else {
				initialPoint =  pt;
				panning = YES;
			}
		}

			break;
			
        default:
        {
			
            // handle multi touch
            UITouch *touch1 = [[allTouches allObjects] objectAtIndex:0];
            UITouch *touch2 = [[allTouches allObjects] objectAtIndex:1];
			
			CGPoint viewPoint1 = [touch1 locationInView:self];
			CGPoint viewPoint2 = [touch2 locationInView:self];
            
            middle.x = (viewPoint1.x + viewPoint2.x)/2;
            middle.y = (viewPoint1.y + viewPoint2.y)/2;
			

			initialDistance = [self distanceBetweenTwoPoints:viewPoint1 toPoint:viewPoint2]; 	
			
			if (initialDistance == 0)
				initialDistance = -1;
			
			initialScaleX = svgRenderer.globalScaleX;
			initialScaleY = svgRenderer.globalScaleY;			




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
				svgLayer.frame = CGRectMake(origin.x,origin.y, svgRenderer.documentSize.width, 
												svgRenderer.documentSize.height);	
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
				
				float oldScale = svgRenderer.globalScaleX;
				float pinchScale = currentDistance / initialDistance;
				svgRenderer.globalScaleX = initialScaleX * pinchScale;
				svgRenderer.globalScaleY = initialScaleY * pinchScale;
				
				 
				float factor = svgRenderer.globalScaleX/oldScale;
				
				origin.x = (1-factor)*middle.x + factor*origin.x;
				origin.y = (1-factor)*middle.y + factor*origin.y;
				
				
				svgLayer.frame = CGRectMake(origin.x,origin.y, svgRenderer.documentSize.width * pinchScale, 
											svgRenderer.documentSize.height * pinchScale);	
				
				
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
			UITouch *touch1 = [[allTouches allObjects] objectAtIndex:0];				
			CGPoint point1 = [touch1 locationInView:self];
			//highlight nearby star				
			NSString* name = [svgRenderer find:point1];
            NSLog(@"name %@",name);
			BOOL doRender = NO;
			if (!name)
				doRender = selectedLocation ? YES : NO;	
			else
				doRender = ![name isEqualToString:selectedLocation];			
			
			
			if (!name)
				selectedLocation = nil;
			else 
				selectedLocation = [NSString stringWithString:name];	
			
			if (delegate)
				[delegate singleTap:selectedLocation];

			
			if (origin.x != self.frame.origin.x || origin.y != self.frame.origin.y)
			{
				
				svgLayer.frame = CGRectMake(self.frame.origin.x,self.frame.origin.y, svgRenderer.documentSize.width, 
											svgRenderer.documentSize.height);
			
				//shift origin in renderer
				svgRenderer.offsetX -= (origin.x - self.frame.origin.x);
				svgRenderer.offsetY -= (origin.y - self.frame.origin.y);
				origin = self.frame.origin;				
			
					
				doRender = true;
			}
            if (doRender)
                [svgRenderer redraw];
			break;
        default:
			if (initialDistance > 0)
			{
				
				svgLayer.frame = CGRectMake(self.frame.origin.x,self.frame.origin.y, svgRenderer.documentSize.width, 
											svgRenderer.documentSize.height);
				
								

				// (originBegin + middle)/initialScale = (originEnd + middle)/finalScale
				// originBegin * finalScale + middle * finalScale = originEnd * initialScale + middle * initialScale
				// (originBegin * finalScale + middle * ( finalScale - initialScale))/initialScale = originEnd
								
				
				svgRenderer.offsetX = (svgRenderer.offsetX * svgRenderer.globalScaleX + middle.x * (svgRenderer.globalScaleX - initialScaleX))/initialScaleX;
				svgRenderer.offsetY = (svgRenderer.offsetY * svgRenderer.globalScaleY + middle.y * (svgRenderer.globalScaleY - initialScaleY))/initialScaleY;
				

				origin = self.frame.origin;
				
				 [svgRenderer redraw];									
			}
			initialDistance = -1;			
            break;
	}
	
	[super touchesEnded:touches withEvent:event];


}

//location is (x,y) coordinate of point in unscaled image
-(void) locate:(CGPoint)location withBoundingBox:(CGSize)box
{
	[svgRenderer center:location withBoundingBox:box];	
}


-(void)dealloc
{
	[svgRenderer release];
    if (svgDrawing != NULL)
	   CGImageRelease(svgDrawing);
	[svgLayer release];
    [spinner release];
	[super dealloc];
}

@end
