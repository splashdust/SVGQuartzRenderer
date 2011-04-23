/*--------------------------------------------------
 * Copyright (c) 2011 Aaron Boxer
 * 
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *--------------------------------------------------*/

//
//  SVGStyle.h
//  SVGRendererTouch
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
    BOOL isHighlighted;

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
@property (nonatomic) BOOL isHighlighted;


- (void)reset;
- (void) setFillColorFromAttribute:(NSString *)attr;
- (void) setFillColorFromInt:(unsigned int)color;
- (void)setStyleContext:(NSString *)style withDefDict:(NSDictionary*)defDict;
- (void)drawPath:(CGPathRef)path withContext:(CGContextRef)context;
-(void) setUpStroke:(CGContextRef)context;
+(unsigned int) extractColorFromAttribute:(NSString*)attr;

CGImageRef imageFromBase64(NSString *b64Data);

@end
