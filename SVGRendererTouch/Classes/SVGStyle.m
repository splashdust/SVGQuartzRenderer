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
//  SVGStyle.m
//  SVGRendererTouch


#import "SVGStyle.h"
#import "NSData+Base64.h"


// Also, the style object could be responsible for parsing CSS and for configuring
// the CGContext according to it's 


@interface SVGStyle (private)

    void drawImagePattern(void * fillPatDescriptor, CGContextRef context);
    - (NSDictionary *)getCompleteDefinitionFromID:(NSString *)identifier withDefDict:(NSDictionary*)defDict;

@end

@implementation SVGStyle

@synthesize styleString;
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
    if ((self = [super init])) {
      	 doStroke = NO;
		strokeColor = 0;
		 strokeWidth = 1.0;
		fillPattern=NULL;
		fillGradient=NULL;
    }
    return self;
}

-(id)copyWithZone:(NSZone *)zone
{
	// We'll ignore the zone for now
	SVGStyle *another = [SVGStyle new];
	another.doFill = doFill;
	
	
	another.styleString = styleString;
	another.fillColor = fillColor;
	another.fillOpacity = fillOpacity;
	another.doStroke = doStroke;
	another.strokeColor = strokeColor ;
	another.strokeWidth = strokeWidth;
	another.strokeOpacity = strokeOpacity;
	another.lineJoinStyle = lineJoinStyle;
	another.lineCapStyle = lineCapStyle;
	another.miterLimit = miterLimit;
	another.fillPattern = NULL;
	another.fillType = fillType;
	another.fillGradient = NULL;
	another.fillGradientPoints = fillGradientPoints;
	another.fillGradientAngle = fillGradientAngle;
	another.fillGradientCenterPoint = fillGradientCenterPoint;
	another.font = font;
	another.fontSize = fontSize;

	
	return another;
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
	styleString = nil;
}


- (void)setStyleContext:(NSString *)style withDefDict:(NSDictionary*)defDict
{
	NSAutoreleasePool *pool =  [[NSAutoreleasePool alloc] init];
	
	// Scan the style string and parse relevant data
	// -------------------------------------------------------------------------
	NSScanner *cssScanner = [NSScanner scannerWithString:style];
	[cssScanner setCaseSensitive:YES];
	[cssScanner setCharactersToBeSkipped:[NSCharacterSet newlineCharacterSet]];
	
	NSString *currentAttribute;
	while ([cssScanner scanUpToString:@";" intoString:&currentAttribute]) {
		NSArray *attrAr = [currentAttribute componentsSeparatedByString:@":"];
		
		NSString *attrName = [attrAr objectAtIndex:0];
		NSString *attrValue = [attrAr objectAtIndex:1];
		
		// --------------------- FILL
		if([attrName isEqualToString:@"fill"]) {
			if(![attrValue isEqualToString:@"none"] && [attrValue rangeOfString:@"url"].location == NSNotFound) {
				
				doFill = YES;
				fillType = @"solid";
				[self setFillColorFromAttribute:attrValue];
				
			} else if([attrValue rangeOfString:@"url"].location != NSNotFound) {
				
				doFill = YES;
				NSScanner *scanner = [NSScanner scannerWithString:attrValue];
				[scanner setCaseSensitive:YES];
				[scanner setCharactersToBeSkipped:[NSCharacterSet newlineCharacterSet]];
				
				NSString *url;
				[scanner scanString:@"url(" intoString:nil];
				[scanner scanUpToString:@")" intoString:&url];
				
				if([url hasPrefix:@"#"]) {
					// Get def by ID
					NSDictionary *def = [self getCompleteDefinitionFromID:url withDefDict:defDict];
					if([def objectForKey:@"images"] && [[def objectForKey:@"images"] count] > 0) {
						
						// Load bitmap pattern
						fillType = [def objectForKey:@"type"];
						NSString *imgString = [[[def objectForKey:@"images"] objectAtIndex:0] objectForKey:@"xlink:href"];
						CGImageRef patternImage = imageFromBase64(imgString);
						
						CGImageRetain(patternImage);
						
						FillPatternDescriptor desc;
						desc.imgRef = patternImage;
						desc.rect = CGRectMake(0, 0, 
											   [[[[def objectForKey:@"images"] objectAtIndex:0] objectForKey:@"width"] floatValue], 
											   [[[[def objectForKey:@"images"] objectAtIndex:0] objectForKey:@"height"] floatValue]);
						CGPatternCallbacks callbacks = { 0, &drawImagePattern, NULL };
						
						CGPatternRelease(fillPattern);
						fillPattern = CGPatternCreate (
																	/* info */		&desc,
																	/* bounds */	desc.rect,
																	/* matrix */	CGAffineTransformIdentity,
																	/* xStep */		desc.rect.size.width,
																	/* yStep */		desc.rect.size.height,
																	/* tiling */	kCGPatternTilingConstantSpacing,
																	/* isColored */	true,
																	/* callbacks */	&callbacks);
						
						
					} else if([def objectForKey:@"stops"] && [[def objectForKey:@"stops"] count] > 0) {
						// Load gradient
						fillType = [def objectForKey:@"type"];
						if([def objectForKey:@"x1"]) {
							FILL_GRADIENT_POINTS gradientPoints;
							gradientPoints.start = CGPointMake([[def objectForKey:@"x1"] floatValue] ,[[def objectForKey:@"y1"] floatValue] );
							gradientPoints.end = CGPointMake([[def objectForKey:@"x2"] floatValue] ,[[def objectForKey:@"y2"] floatValue] );
							fillGradientPoints = gradientPoints;
							//fillGradientAngle = (((atan2(([[def objectForKey:@"x1"] floatValue] - [[def objectForKey:@"x2"] floatValue]),
							//											([[def objectForKey:@"y1"] floatValue] - [[def objectForKey:@"y2"] floatValue])))*180)/M_PI)+90;
						} if([def objectForKey:@"cx"]) {
							fillGradientCenterPoint = CGPointMake([[def objectForKey:@"cx"] floatValue], [[def objectForKey:@"cy"] floatValue]) ;
						}
						
						NSArray *stops = [def objectForKey:@"stops"];
						
						CGFloat colors[[stops count]*4];
						CGFloat locations[[stops count]];
						int ci=0;
						for(int i=0;i<[stops count];i++) {
							unsigned int stopColorRGB = 0;
							CGFloat stopColorAlpha = 1;
							
							NSString *style = [[stops objectAtIndex:i] objectForKey:@"style"];
							NSArray *styles = [style componentsSeparatedByString:@";"];
							for(int si=0;si<[styles count];si++) {
								NSArray *valuePair = [[styles objectAtIndex:si] componentsSeparatedByString:@":"];
								if([valuePair count]==2) {
									if([[valuePair objectAtIndex:0] isEqualToString:@"stop-color"]) {
										// Handle color
										NSScanner *hexScanner = [NSScanner scannerWithString:
																 [[valuePair objectAtIndex:1] stringByReplacingOccurrencesOfString:@"#" withString:@"0x"]];
										[hexScanner scanHexInt:&stopColorRGB];
									}
									if([[valuePair objectAtIndex:0] isEqualToString:@"stop-opacity"]) {
										stopColorAlpha = [[valuePair objectAtIndex:1] floatValue];
									}
								}
							}
							
							CGFloat red   = ((stopColorRGB & 0xFF0000) >> 16) / 255.0f;
							CGFloat green = ((stopColorRGB & 0x00FF00) >>  8) / 255.0f;
							CGFloat blue  =  (stopColorRGB & 0x0000FF) / 255.0f;
							colors[ci++] = red;
							colors[ci++] = green;
							colors[ci++] = blue;
							colors[ci++] = stopColorAlpha;
							
							locations[i] = [[[stops objectAtIndex:i] objectForKey:@"offset"] floatValue];
						}
						
						
						CGGradientRelease(fillGradient);
						fillGradient = CGGradientCreateWithColorComponents(CGColorSpaceCreateDeviceRGB(),
																						colors, 
																						locations,
																						[stops count]);
					}
				}
			} else {
				doFill = NO;
			}
			
		}
		
		// --------------------- FILL-OPACITY
		if([attrName isEqualToString:@"fill-opacity"]) {
			NSScanner *floatScanner = [NSScanner scannerWithString:attrValue];
			[floatScanner scanFloat:&fillColor.a];
		}
		
		// --------------------- STROKE
		if([attrName isEqualToString:@"stroke"]) {
			if(![attrValue isEqualToString:@"none"]) {
				doStroke = YES;
				strokeColor = [SVGStyle extractColorFromAttribute:attrValue];
				strokeWidth = 1;
			} else {
				doStroke = NO;
			}
			
		}
		
		// --------------------- STROKE-OPACITY
		if([attrName isEqualToString:@"stroke-opacity"]) {
			NSScanner *floatScanner = [NSScanner scannerWithString:attrValue];
			[floatScanner scanFloat:&strokeOpacity];
		}
		
		// --------------------- STROKE-WIDTH
		if([attrName isEqualToString:@"stroke-width"]) {
			NSScanner *floatScanner = [NSScanner scannerWithString:
									   [attrValue stringByReplacingOccurrencesOfString:@"px" withString:@""]];
			[floatScanner scanFloat:&strokeWidth];
			
		}
		
		// --------------------- STROKE-LINECAP
		if([attrName isEqualToString:@"stroke-linecap"]) {
			NSScanner *stringScanner = [NSScanner scannerWithString:attrValue];
			NSString *lineCapValue;
			[stringScanner scanUpToString:@";" intoString:&lineCapValue];
			
			if([lineCapValue isEqualToString:@"butt"])
				lineCapStyle = kCGLineCapButt;
			
			if([lineCapValue isEqualToString:@"round"])
				lineCapStyle = kCGLineCapRound;
			
			if([lineCapValue isEqualToString:@"square"])
				lineCapStyle = kCGLineCapSquare;
		}
		
		// --------------------- STROKE-LINEJOIN
		if([attrName isEqualToString:@"stroke-linejoin"]) {
			NSScanner *stringScanner = [NSScanner scannerWithString:attrValue];
			NSString *lineCapValue;
			[stringScanner scanUpToString:@";" intoString:&lineCapValue];
			
			if([lineCapValue isEqualToString:@"miter"])
				lineJoinStyle = kCGLineJoinMiter;
			
			if([lineCapValue isEqualToString:@"round"])
				lineJoinStyle = kCGLineJoinRound;
			
			if([lineCapValue isEqualToString:@"bevel"])
				lineJoinStyle = kCGLineJoinBevel;
		}
		
		// --------------------- STROKE-MITERLIMIT
		if([attrName isEqualToString:@"stroke-miterlimit"]) {
			NSScanner *floatScanner = [NSScanner scannerWithString:attrValue];
			[floatScanner scanFloat:&miterLimit];
		}
		
		// --------------------- FONT-SIZE
		if([attrName isEqualToString:@"font-size"]) {
			NSScanner *floatScanner = [NSScanner scannerWithString:attrValue];
			[floatScanner scanFloat:&fontSize];
		}
		
		// --------------------- FONT-STYLE
		if([attrName isEqualToString:@"font-style"]) {
			
		}
		
		// --------------------- FONT-WEIGHT
		if([attrName isEqualToString:@"font-weight"]) {
			
		}
		
		// --------------------- LINE-HEIGHT
		if([attrName isEqualToString:@"line-height"]) {
			
		}
		
		// --------------------- LETTER-SPACING
		if([attrName isEqualToString:@"letter-spacing"]) {
			
		}
		
		// --------------------- WORD-SPACING
		if([attrName isEqualToString:@"word-spacing"]) {
			
		}
		
		// --------------------- FONT-FAMILY
		if([attrName isEqualToString:@"font-family"]) {
			font = [attrValue retain];
			if([font isEqualToString:@"Sans"])
				font = @"Helvetica";
		}
		
		[cssScanner scanString:@";" intoString:nil];
	}
	[pool release];
}

- (NSDictionary *)getCompleteDefinitionFromID:(NSString *)identifier withDefDict:(NSDictionary*)defDict
{
	NSString *theId = [identifier stringByReplacingOccurrencesOfString:@"#" withString:@""];
	NSMutableDictionary *def = [defDict objectForKey:theId];
	NSString *xlink = [def objectForKey:@"xlink:href"];
	while(xlink){
		NSMutableDictionary *linkedDef = [defDict objectForKey:
										  [xlink stringByReplacingOccurrencesOfString:@"#" withString:@""]];
		
		if([linkedDef objectForKey:@"images"])
			[def setObject:[linkedDef objectForKey:@"images"] forKey:@"images"];
		
		if([linkedDef objectForKey:@"stops"])
			[def setObject:[linkedDef objectForKey:@"stops"] forKey:@"stops"];
		
		xlink = [linkedDef objectForKey:@"xlink:href"];
	}
	
	return def;
}

-(void) setUpStroke:(CGContextRef)context
{
	CGFloat red   = ((strokeColor & 0xFF0000) >> 16) / 255.0f;
	CGFloat green = ((strokeColor & 0x00FF00) >>  8) / 255.0f;
	CGFloat blue  =  (strokeColor & 0x0000FF) / 255.0f;
	CGContextSetRGBStrokeColor(context, red, green, blue, strokeOpacity);
	CGContextSetLineWidth(context, strokeWidth);
	CGContextSetLineCap(context, lineCapStyle);
	CGContextSetLineJoin(context, lineJoinStyle);
	CGContextSetMiterLimit(context, miterLimit);
	
	
}

+(unsigned int) extractColorFromAttribute:(NSString*)attr
{
	NSScanner *hexScanner = [NSScanner scannerWithString:
							 [attr stringByReplacingOccurrencesOfString:@"#" withString:@"0x"]];
	[hexScanner setCharactersToBeSkipped:[NSCharacterSet symbolCharacterSet]]; 
	unsigned int color;
	[hexScanner scanHexInt:&color];	
	return color;
}


// Draw a path based on style information
// -----------------------------------------------------------------------------
- (void)drawPath:(CGMutablePathRef)path withContext:(CGContextRef)context
{				
	if(doFill) {
		if ([fillType isEqualToString:@"solid"]) {
			
			//NSLog(@"Setting fill color R:%f, G:%f, B:%f, A:%f", fillColor.r, fillColor.g, fillColor.b, fillColor.a);
			CGContextSetRGBFillColor(context, fillColor.r, fillColor.g, fillColor.b, fillColor.a);
			
		} else if([fillType isEqualToString:@"pattern"]) {
			
			CGColorSpaceRef myColorSpace = CGColorSpaceCreatePattern(NULL);
			CGContextSetFillColorSpace(context, myColorSpace);
			CGColorSpaceRelease(myColorSpace);
			
			CGFloat alpha = fillColor.a;
			CGContextSetFillPattern (context,
									 fillPattern,
									 &alpha);
			
		} else if([fillType isEqualToString:@"linearGradient"]) {
			
			doFill = NO;
			CGContextAddPath(context, path);
			CGContextSaveGState(context);
			CGContextClip(context);
			CGContextDrawLinearGradient(context, fillGradient, fillGradientPoints.start, fillGradientPoints.end, 3);
			CGContextRestoreGState(context);
			
		} else if([fillType isEqualToString:@"radialGradient"]) {
			
			doFill = NO;
			CGContextAddPath(context, path);
			CGContextSaveGState(context);
			CGContextClip(context);
			CGContextDrawRadialGradient(context, fillGradient, fillGradientCenterPoint, 0, fillGradientCenterPoint, fillGradientPoints.start.y, 3);
			CGContextRestoreGState(context);
			
		}
	}
	
	// Do the drawing
	// -------------------------------------------------------------------------
	if(doStroke) {
		[self setUpStroke:context];		
	}
	
	if(doFill || doStroke) {
		CGContextAddPath(context, path);
		//NSLog(@"Adding path to contextl");
	}
	
	if(doFill && doStroke) {
		CGContextDrawPath(context, kCGPathFillStroke);
	} else if(doFill) {
		CGContextFillPath(context);
		//NSLog(@"Filling path in contextl");
	} else if(doStroke) {
		CGContextStrokePath(context);
	}	
	
}


void drawImagePattern(void * fillPatDescriptor, CGContextRef context)
{
	FillPatternDescriptor *patDesc = (FillPatternDescriptor *)fillPatDescriptor;
	CGContextDrawImage(context, patDesc->rect, patDesc->imgRef);
	CGImageRelease(patDesc->imgRef);
	patDesc->imgRef = NULL;
}


CGImageRef imageFromBase64(NSString *b64Data)
{
	NSArray *mimeAndData = [b64Data componentsSeparatedByString:@","];
	NSData *imgData = [NSData dataWithBase64EncodedString:[mimeAndData objectAtIndex:1]];
	CGDataProviderRef provider = CGDataProviderCreateWithCFData((CFDataRef)imgData);
	
	CGImageRef img=nil;
	if([[mimeAndData objectAtIndex:0] isEqualToString:@"data:image/jpeg;base64"])
		img = CGImageCreateWithJPEGDataProvider(provider, NULL, true, kCGRenderingIntentDefault);
	else if([[mimeAndData objectAtIndex:0] isEqualToString:@"data:image/png;base64"])
		img = CGImageCreateWithPNGDataProvider(provider, NULL, true, kCGRenderingIntentDefault);
	CGDataProviderRelease(provider);
	return img;
}


-(void) setFillColorFromAttribute:(NSString*)attr
{
	unsigned int color = [SVGStyle extractColorFromAttribute:attr];
	[self setFillColorFromInt:color];

}

- (void) setFillColorFromInt:(unsigned int)color
{
    fillColor.r = ((color & 0xFF0000) >> 16) / 255.0f;
	fillColor.g = ((color & 0x00FF00) >>  8) / 255.0f;
	fillColor.b =  (color & 0x0000FF) / 255.0f;
	fillColor.a = 1;	
	
}

- (void)dealloc
{
	[font release];
	font = nil;
	CGGradientRelease(fillGradient);
	fillGradient = NULL;
	CGPatternRelease(fillPattern);
	fillPattern = NULL;
	[super dealloc];
}

@end
