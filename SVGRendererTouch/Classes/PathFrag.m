//
//  PathFrag.m
//  SVGRendererTouch
//
//  Created by Aaron Boxer on 11-04-19.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "PathFrag.h"

@interface PathFrag (private)
- (CGAffineTransform)getTransform;

@end


@implementation PathFrag

@synthesize path;

-(id)copyWithZone:(NSZone *)zone
{ 
    PathFrag* another = [PathFrag new];
    another.style = [style copyWithZone:nil];
    another.transform = transform;
    another.path = CGPathCreateMutableCopy(path);
    
    return another;
}

-(void) draw:(CGContextRef)context
{	
 		
	// Apply to graphics context
    CGAffineTransform globalTransform = [self getTransform];
	CGContextConcatCTM(context,globalTransform);    
    
    [self.style drawPath:path withContext:context];
    
    CGContextConcatCTM(context,CGAffineTransformInvert(globalTransform));
}

- (CGAffineTransform)getTransform
{
    CGPoint scale = [transProvider getScale];
    CGPoint translation = [transProvider getTranslation];
    float currentScaleX = scale.x;
	float currentScaleY = scale.y;
    

	CGAffineTransform globalTrans = CGAffineTransformIdentity;
    
    float a = transform.a;
    float b = transform.b;
    float c = transform.c;
    float d = transform.d;
    float tx = transform.tx;
    float ty = transform.ty;
    
    
	// Matrix
	if (transformType == AFFINE)
	{	
        
        // local translation, with correction for global scale, and global offset	
        tx = tx*scale.x + translation.x;
        ty = ty*scale.y + translation.y;
        
        // transfer all scaling to single transformation
        currentScaleX *= a;
        currentScaleY *= d;
        
        a = 1;
        b /= d;
        c /= a;
        d = 1;
        
        //move all scaling into separate transformation
        if (currentScaleX != 1.0 || currentScaleY != 1.0)
            globalTrans = CGAffineTransformMakeScale(currentScaleX, currentScaleY);
        
        
        CGAffineTransform matrixTransform = CGAffineTransformMake (a,b,c,d, tx, ty);
        
        globalTrans = CGAffineTransformConcat(globalTrans, matrixTransform);
        
        return globalTrans;
        
		
	}
	
	
	// Scale
	if (transformType == SCALE)
	{			
        currentScaleX *= a;
        currentScaleY *= d;		
        
	}
	if (currentScaleX != 1.0 || currentScaleY != 1.0)
		globalTrans = CGAffineTransformScale(globalTrans, currentScaleX, currentScaleY);
	
	
	// Rotate
	if ( (transformType == ROT) && a != 0)
	{
        globalTrans = CGAffineTransformRotate(globalTrans, a);		
	}
    
	
	// Translate
	float transX = translation.x/currentScaleX;
	float transY = translation.y/currentScaleY;
    
	if (transformType == TRANS)
	{	
        transX += tx;
        transY += ty;								
	}
	
	if (transX != 0 || transY != 0)
		globalTrans = CGAffineTransformTranslate(globalTrans, transX, transY);			
    

    return globalTrans;
    
}


-(void) wrap:(CGPathRef)apath style:(SVGStyle*) astyle transform:(CGAffineTransform)atransform type:(enum TRANSFORMATION_TYPE)atype
{
    [super wrap:astyle transform:atransform type:atype];
    self.path = apath;
    
}


- (void)dealloc
{
    CGPathRelease(path);
    [super dealloc];
    
}


@end
