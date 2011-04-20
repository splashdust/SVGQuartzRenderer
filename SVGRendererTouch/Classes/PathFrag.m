//
//  PathFrag.m
//  SVGRendererTouch
//
//  Created by Aaron Boxer on 11-04-19.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "PathFrag.h"


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
	CGContextConcatCTM(context,transform);    
    
    [self.style drawPath:path withContext:context];
    
    CGContextConcatCTM(context,CGAffineTransformInvert(transform));
}

-(id) initWithPath:(CGPathRef)apath style:(SVGStyle*) astyle transform:(CGAffineTransform)atransform
{
    if (( self = [super initWithStyle:astyle transform:atransform]))
    {
        self.path = CGPathCreateMutableCopy(apath);
    }
    
    return self;
    
}


- (void)dealloc
{
    CGPathRelease(path);
    [super dealloc];
    
}


@end
