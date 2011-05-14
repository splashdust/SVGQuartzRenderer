//
//  TextFrag.h
//  SVGRendererTouch
//
//  Created by Aaron Boxer on 11-05-13.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GraphicFrag.h"

@interface TextFrag : GraphicFrag {
    CGPoint location;
    char* text;
}

-(void) wrap:(char*)text location:(CGPoint)loc style:(SVGStyle*) astyle transform:(CGAffineTransform)atransform type:(enum TRANSFORMATION_TYPE)atype;

@end
