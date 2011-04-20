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
   	CGMutablePathRef path; 
}
@property (nonatomic) CGMutablePathRef path;

-(id) initWithPath:(CGPathRef)apath style:(SVGStyle*) astyle transform:(CGAffineTransform)atransform;
@end
