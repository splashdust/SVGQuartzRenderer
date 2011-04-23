//
//  GraphicFrag.m
//  SVGRendererTouch
//
//  Created by Aaron Boxer on 11-04-19.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "GraphicFrag.h"


@implementation GraphicFrag

@synthesize style, transform, isHighlighted;

-(id)copyWithZone:(NSZone *)zone
{ 
    GraphicFrag* another = [GraphicFrag new];
    another.style = [style copyWithZone:nil];
    another.transform = transform;
    
    return another;
}


-(void) draw:(CGContextRef)context
{
    
}

-(BOOL) isHighlighted
{
    BOOL rc = NO;
    if (style)
        rc = style.isHighlighted;
    return rc;
    
}
-(void) setIsHighlighted:(BOOL)highlighted
{
    if (style)
        style.isHighlighted = highlighted;
}

-(void) wrap:(SVGStyle*)astyle transform:(CGAffineTransform)atransform type:(enum TRANSFORMATION_TYPE)atype;
{

    self.style = astyle;
    self.transform = atransform;
    transformType = atype;


}

-(id) init:(id<ITransProvider>)provider
{
    if ((self = [super init]))
    {
        transProvider = [provider retain];
        
    }
    return self;
    
}

- (void)dealloc
{
    [transProvider release];
    [style release];
    [super dealloc];
    
}




@end
