//
//  GraphicFrag.h
//  SVGRendererTouch
//
//  Created by Aaron Boxer on 11-04-19.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SVGStyle.h"

@interface GraphicFrag : NSObject {
@protected
    CGAffineTransform transform;
    SVGStyle* style;
}

@property (retain, nonatomic) SVGStyle* style;
@property (nonatomic) CGAffineTransform transform;

-(void) draw:(CGContextRef)context;
-(id) initWithStyle:(SVGStyle*) astyle transform:(CGAffineTransform)atransform;

@end
