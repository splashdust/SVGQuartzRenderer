/*--------------------------------------------------
 * Copyright (c) 2011 Aaron Boxer
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
//
//  Sprite.m
//  SVGRendererTouch


#import "Sprite.h"
#import "float.h"



@implementation Sprite

@synthesize isHighlighted;
@synthesize boundingRect;
@synthesize name;


-(id) init
{
  if ((self = [super init]))
  {
	  minX = FLT_MAX;
	  minY = FLT_MAX;
	  maxX = FLT_MIN;
	  maxY = FLT_MIN;
	  
	  initialized = NO;
	  
  }
	
  return self; 	
}

-(id) initWithBoundingRect:(CGRect)rect
{
	
	if ((self = [super init]))
	{
		boundingRect = rect;
		
		initialized = YES;
		
	}
	
	return self; 
	
}


-(void) adjustBoundingBox:(CGPoint)pathPoint
{
	if (pathPoint.x < minX)
		minX = pathPoint.x;
	if (pathPoint.y < minY)
		minY = pathPoint.y;	
	if (pathPoint.x > maxX)
		maxX = pathPoint.x;
	if (pathPoint.y > maxY)
		maxY = pathPoint.y;		
	
}

-(void) finishCalcBoundingBox:(CGAffineTransform)xform
{
	
	boundingRect = CGRectApplyAffineTransform(CGRectMake(minX, minY, maxX-minX, maxY-minY), xform);	
	initialized = TRUE;
	
}

-(BOOL) isInitialized
{
	
	return initialized;	
}

@end
