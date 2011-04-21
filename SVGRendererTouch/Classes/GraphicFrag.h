//
//  GraphicFrag.h
//  SVGRendererTouch
//
//  Created by Aaron Boxer on 11-04-19.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SVGStyle.h"
#import "IDrawable.h"

const enum TRANSFORMATION_TYPE {TRANS,ROT,SCALE,AFFINE};

@interface GraphicFrag : NSObject<IDrawable> {
@protected
    CGAffineTransform transform;
    SVGStyle* style;
    enum TRANSFORMATION_TYPE transformType;
}

@property (retain, nonatomic) SVGStyle* style;
@property (nonatomic) CGAffineTransform transform;

-(void) draw:(CGContextRef)context;
-(void) wrap:(SVGStyle*) astyle transform:(CGAffineTransform)atransform;

@end
