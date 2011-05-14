//
//  TextFrag.m
//  SVGRendererTouch
//
//  Created by Aaron Boxer on 11-05-13.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "TextFrag.h"


@implementation TextFrag



-(void) doDraw:(CGContextRef)context
{
    [style drawText:text :location withContext:context];
}

-(void) wrap:(char*)txt location:(CGPoint)loc style:(SVGStyle*) astyle transform:(CGAffineTransform)atransform type:(enum TRANSFORMATION_TYPE)atype
{
    [super wrap:astyle transform:atransform type:atype];
    text = txt;
    location = loc;
}

-(id) init
{
    if ((self = [super init]))
    {
        text = NULL;
        
    }
    return self;
    
}

- (void)dealloc
{
    if (text)
        free(text);
    [super dealloc];
    
}

@end
