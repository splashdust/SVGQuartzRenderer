//
//  SVGStyle.h
//  SVGRendererTouch
//
//  Created by Aaron Boxer on 11-03-24.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef struct
{
	CGFloat r;
	CGFloat g;
	CGFloat b;
	CGFloat a;
	
} FILL_COLOR;

typedef struct
{
	CGPoint start;
	CGPoint end;	
	
} FILL_GRADIENT_POINTS;

@interface SVGStyle : NSObject {

	BOOL doFill;
	FILL_COLOR fillColor;
	float fillOpacity;
	BOOL doStroke;
	unsigned int strokeColor ;
	float strokeWidth ;
	float strokeOpacity;
	CGLineJoin lineJoinStyle;
	CGLineCap lineCapStyle;
	float miterLimit;
	CGPatternRef fillPattern;
	NSString *fillType;
	CGGradientRef fillGradient;
	FILL_GRADIENT_POINTS fillGradientPoints;
	int fillGradientAngle;
	CGPoint fillGradientCenterPoint;
	NSString *font;
	float fontSize;
}

@property (nonatomic) FILL_GRADIENT_POINTS fillGradientPoints;
@property (nonatomic) FILL_COLOR fillColor;
@property (nonatomic) BOOL doFill;
@property (nonatomic) float fillOpacity;
@property (nonatomic) BOOL doStroke;
@property (nonatomic) unsigned int strokeColor ;
@property (nonatomic) float strokeWidth ;
@property (nonatomic) float strokeOpacity;
@property (nonatomic) CGLineJoin lineJoinStyle;
@property (nonatomic) CGLineCap lineCapStyle;
@property (nonatomic) float miterLimit;
@property (nonatomic) CGPatternRef fillPattern;
@property (nonatomic, copy) NSString *fillType;
@property (nonatomic) CGGradientRef fillGradient;
@property (nonatomic) int fillGradientAngle;
@property (nonatomic) CGPoint fillGradientCenterPoint; 
@property (nonatomic, copy) NSString* font; 
@property (nonatomic) float fontSize;


- (void)reset;
-(void) setFillColorFromInt:(unsigned int)color;
-(void) setFillColorAlpha:(float)alpha;

@end
