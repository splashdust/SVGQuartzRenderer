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


-(void) doDraw:(CGContextRef)context
{
    [self.style drawPath:path withContext:context];
    
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
