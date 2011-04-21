//
//  PathFrag.h
//  SVGRendererTouch
//
//  Created by Aaron Boxer on 11-04-19.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GraphicFrag.h"

@interface PathFrag : GraphicFrag {
@private
   	CGPathRef path; 
}
@property (nonatomic) CGPathRef path;

-(void) wrap:(CGPathRef)apath style:(SVGStyle*) astyle transform:(CGAffineTransform)atransform;
@end
