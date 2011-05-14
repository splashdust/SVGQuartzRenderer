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
#import "ITransProvider.h"

const enum TRANSFORMATION_TYPE {TRANS,ROT,SCALE,AFFINE};

typedef struct 
{
    enum TRANSFORMATION_TYPE type;
    CGAffineTransform transform;    
    
} SVG_TRANS;


@interface GraphicFrag : NSObject<IDrawable> {
@protected
    CGAffineTransform transform;
    SVGStyle* style;
    enum TRANSFORMATION_TYPE transformType;
    id<ITransProvider> transProvider;
}

@property (retain, nonatomic) SVGStyle* style;
@property (nonatomic) CGAffineTransform transform;

-(void) draw:(CGContextRef)context;
-(void) doDraw:(CGContextRef)context;
-(void) wrap:(SVGStyle*) astyle transform:(CGAffineTransform)atransform type:(enum TRANSFORMATION_TYPE)atype;
-(id) init:(id<ITransProvider>)provider;
- (CGAffineTransform)getTransform;

@property (nonatomic) BOOL isHighlighted;

@end
