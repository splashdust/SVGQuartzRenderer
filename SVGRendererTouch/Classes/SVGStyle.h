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

struct FillPatternDescriptor {
	CGImageRef imgRef;
	CGRect rect;
}; 

typedef struct FillPatternDescriptor FillPatternDescriptor;

@interface SVGStyle : NSObject <NSCopying>  {

	NSString* styleString;
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
	BOOL isActive;
}
@property (nonatomic, copy) NSString *styleString;
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
@property (nonatomic) BOOL isActive;


- (void)reset;
- (void) setFillColorFromAttribute:(NSString *)attr;
- (void) setFillColorFromInt:(unsigned int)color;
- (void)setStyleContext:(NSString *)style withDefDict:(NSDictionary*)defDict;
- (void)drawPath:(CGMutablePathRef)path withContext:(CGContextRef)context;
-(void) setUpStroke:(CGContextRef)context;
+(unsigned int) extractColorFromAttribute:(NSString*)attr;

CGImageRef imageFromBase64(NSString *b64Data);

@end
