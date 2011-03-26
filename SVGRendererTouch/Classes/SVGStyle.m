//
//  SVGStyle.m
//  SVGRendererTouch
//
//  Created by Aaron Boxer on 11-03-24.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "SVGStyle.h"


// Also, the style object could be responsible for parsing CSS and for configuring
// the CGContext according to it's style.


@implementation SVGStyle

@synthesize fillGradientPoints;
@synthesize fillColor;
@synthesize doFill;
@synthesize fillOpacity;
@synthesize doStroke;
@synthesize strokeColor ;
@synthesize strokeWidth ;
@synthesize strokeOpacity;
@synthesize lineJoinStyle;
@synthesize lineCapStyle;
@synthesize miterLimit;
@synthesize fillPattern;
@synthesize fillType;
@synthesize fillGradient;
@synthesize fillGradientAngle;
@synthesize fillGradientCenterPoint; 
@synthesize font; 
@synthesize fontSize;


- (id)init {
    if (self = [super init]) {
      	 doStroke = NO;
		strokeColor = 0;
		 strokeWidth = 1.0;
		fillPattern=NULL;
		fillGradient=NULL;
    }
    return self;
}

- (void)reset
{
	doFill = YES;
	fillColor.r=0;
	fillColor.g=0;
	fillColor.b=0;
	fillColor.a=1;
	doStroke = NO;
	strokeColor = 0;
	strokeWidth = 1.0;
	strokeOpacity = 1.0;
	lineJoinStyle = kCGLineJoinMiter;
	lineCapStyle = kCGLineCapButt;
	miterLimit = 4;
	fillType = @"solid";
	fillGradientAngle = 0;
	fillGradientCenterPoint = CGPointMake(0, 0);
}

-(void) setFillColorFromInt:(unsigned int)color
{
    fillColor.r = ((color & 0xFF0000) >> 16) / 255.0f;
	fillColor.g = ((color & 0x00FF00) >>  8) / 255.0f;
	fillColor.b =  (color & 0x0000FF) / 255.0f;
	fillColor.a = 1;
}
-(void) setFillColorAlpha:(float)alpha
{
	fillColor.a = alpha;
}

@end
