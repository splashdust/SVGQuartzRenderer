//
//  IGraphicFrag.h
//  SVGRendererTouch
//
//  Created by Aaron Boxer on 11-04-20.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>


@protocol IDrawable <NSObject>

-(void) draw:(CGContextRef)context;

@end
