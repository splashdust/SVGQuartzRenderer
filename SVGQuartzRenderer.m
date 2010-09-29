//
//  SVGQuartzRenderer.m
//  SVGRender
//
//  Created by Joacim Magnusson on 2010-09-20.
//  Copyright 2010 Joacim Magnusson. All rights reserved.
//

#import "SVGQuartzRenderer.h"
#import "NSData+Base64.h"

@interface SVGQuartzRenderer (hidden)

	- (void)setStyleContext:(NSString *)style;
	- (void)drawPath:(CGMutablePathRef)path withStyle:(NSString *)style;
	- (void)applyTransformations:(NSString *)transformations;
	- (NSDictionary *)getCompleteDefinitionFromID:(NSString *)identifier;
	
	void CGPathAddRoundRect(CGMutablePathRef path, CGRect rect, float radius);
	void drawImagePattern(void *fillPatDescriptor, CGContextRef context);

@end

@implementation SVGQuartzRenderer

@synthesize documentSize;
@synthesize delegate;
@synthesize scale;

struct FillPatternDescriptor {
	CGImageRef imgRef;
	CGRect rect;
}; typedef struct FillPatternDescriptor FillPatternDescriptor;

typedef void (*CGPatternDrawPatternCallback) (void * info,
											  CGContextRef context);

NSXMLParser* xmlParser;
NSString *svgFileName;
CGAffineTransform transform;
CGContextRef cgContext;
NSMutableDictionary *defDict;
FillPatternDescriptor desc;

NSMutableDictionary *curPat;
NSMutableDictionary *curGradient;
NSMutableDictionary *curFilter;
NSMutableDictionary *curLayer;

BOOL inDefSection = NO;

// Variables for storing style data
// -------------------------------------------------------------------------
BOOL doFill;
float fillColor[4];
float fillOpacity;
BOOL doStroke = NO;
unsigned int strokeColor = 0;
float strokeWidth = 1.0;
float strokeOpacity;
CGLineJoin lineJoinStyle;
CGLineCap lineCapStyle;
float miterLimit;
CGPatternRef fillPattern;
NSString *fillType;
CGGradientRef fillGradient;
CGPoint fillGradientPoints[2];
int fillGradientAngle;
CGPoint fillGradientCenterPoint;
// -------------------------------------------------------------------------

- (id)init {
    self = [super init];
    if (self) {
        xmlParser = [NSXMLParser alloc];
		transform = CGAffineTransformIdentity;

		defDict = [[NSMutableDictionary alloc] init];
		
		scale = 1.0;
    }
    return self;
}

- (void)setDelegate:(id<SVGQuartzRenderDelegate>)rendererDelegate
{
	delegate = rendererDelegate;
}

- (void)resetStyleContext
{
	doFill = YES;
	fillColor[0]=0;
	fillColor[1]=0;
	fillColor[2]=0;
	fillColor[3]=1;
	doStroke = NO;
	strokeColor = 0;
	strokeWidth = 1.0 * scale;
	strokeOpacity = 1.0 * scale;
	lineJoinStyle = kCGLineJoinMiter;
	lineCapStyle = kCGLineCapButt;
	miterLimit = 4;
	fillType = @"solid";
	fillGradientAngle = 0;
	fillGradientCenterPoint = CGPointMake(0, 0);
}

- (void)drawSVGFile:(NSString *)file
{
	svgFileName = file;
	NSData *xml = [[NSData dataWithContentsOfFile:file] autorelease];
	xmlParser = [xmlParser initWithData:xml];
	
	[xmlParser setDelegate:self];
	[xmlParser setShouldResolveExternalEntities:NO];
	[xmlParser parse];
}


// Element began
// -----------------------------------------------------------------------------
- (void)parser:(NSXMLParser *)parser
didStartElement:(NSString *)elementName 
  namespaceURI:(NSString *)namespaceURI
 qualifiedName:(NSString *)qualifiedName
	attributes:(NSDictionary *)attrDict
{
	NSAutoreleasePool *pool =  [[NSAutoreleasePool alloc] init];
	
	// Top level SVG node
	// -------------------------------------------------------------------------
	if([elementName isEqualToString:@"svg"]) {
		documentSize = CGSizeMake([[attrDict valueForKey:@"width"] floatValue] * scale,
							   [[attrDict valueForKey:@"height"] floatValue] * scale);
		
		doStroke = NO;
		
		if(delegate)
			cgContext = [delegate svgRenderer:self requestedCGContextWidthSize:documentSize];
	}
	
	// Definitions
	// -------------------------------------------------------------------------
	if([elementName isEqualToString:@"defs"]) {
		defDict = [[NSMutableDictionary alloc] init];
		inDefSection = YES;
	}
	
		if([elementName isEqualToString:@"pattern"]) {
			curPat = [[NSMutableDictionary alloc] init];
			
			NSEnumerator *enumerator = [attrDict keyEnumerator];
			id key;
			while ((key = [enumerator nextObject])) {
				NSDictionary *obj = [attrDict objectForKey:key];
				[curPat setObject:obj forKey:key];
			}
			[curPat setObject:[[NSMutableArray alloc] init] forKey:@"images"];
			[curPat setObject:@"pattern" forKey:@"type"];
		}
			if([elementName isEqualToString:@"image"]) {
				NSMutableDictionary *imageDict = [[NSMutableDictionary alloc] init];
				NSEnumerator *enumerator = [attrDict keyEnumerator];
				id key;
				while ((key = [enumerator nextObject])) {
					NSDictionary *obj = [attrDict objectForKey:key];
					[imageDict setObject:obj forKey:key];
				}
				[[curPat objectForKey:@"images"] addObject:imageDict];
			}
		
		if([elementName isEqualToString:@"linearGradient"]) {
			curGradient = [[NSMutableDictionary alloc] init];
			NSEnumerator *enumerator = [attrDict keyEnumerator];
			id key;
			while ((key = [enumerator nextObject])) {
				NSDictionary *obj = [attrDict objectForKey:key];
				[curGradient setObject:obj forKey:key];
			}
			[curGradient setObject:@"linearGradient" forKey:@"type"];
			[curGradient setObject:[[NSMutableArray alloc] init] forKey:@"stops"];
		}
			if([elementName isEqualToString:@"stop"]) {
				NSMutableDictionary *stopDict = [[NSMutableDictionary alloc] init];
				NSEnumerator *enumerator = [attrDict keyEnumerator];
				id key;
				while ((key = [enumerator nextObject])) {
					NSDictionary *obj = [attrDict objectForKey:key];
					[stopDict setObject:obj forKey:key];
				}
				[[curGradient objectForKey:@"stops"] addObject:stopDict];
			}
		
		if([elementName isEqualToString:@"radialGradient"]) {
			curGradient = [[NSMutableDictionary alloc] init];
			NSEnumerator *enumerator = [attrDict keyEnumerator];
			id key;
			while ((key = [enumerator nextObject])) {
				NSDictionary *obj = [attrDict objectForKey:key];
				[curGradient setObject:obj forKey:key];
			}
			[curGradient setObject:@"radialGradient" forKey:@"type"];
		}
	
		if([elementName isEqualToString:@"filter"]) {
			curFilter = [[NSMutableDictionary alloc] init];
			NSEnumerator *enumerator = [attrDict keyEnumerator];
			id key;
			while ((key = [enumerator nextObject])) {
				NSDictionary *obj = [attrDict objectForKey:key];
				[curFilter setObject:obj forKey:key];
			}
			[curFilter setObject:[[NSMutableArray alloc] init] forKey:@"feGaussianBlurs"];
		}
			if([elementName isEqualToString:@"feGaussianBlur"]) {
				NSMutableDictionary *blurDict = [[NSMutableDictionary alloc] init];
				NSEnumerator *enumerator = [attrDict keyEnumerator];
				id key;
				while ((key = [enumerator nextObject])) {
					NSDictionary *obj = [attrDict objectForKey:key];
					[blurDict setObject:obj forKey:key];
				}
				[[curFilter objectForKey:@"feGaussianBlurs"] addObject:blurDict];
			}
			if([elementName isEqualToString:@"feColorMatrix"]) {
				
			}
			if([elementName isEqualToString:@"feFlood"]) {
				
			}
			if([elementName isEqualToString:@"feBlend"]) {
				
			}
			if([elementName isEqualToString:@"feComposite"]) {
				
			}
	
	// Group node
	// -------------------------------------------------------------------------
	if([elementName isEqualToString:@"g"]) {
		
		curLayer = [[NSMutableDictionary alloc] init];
		NSEnumerator *enumerator = [attrDict keyEnumerator];
		id key;
		while ((key = [enumerator nextObject])) {
			NSDictionary *obj = [attrDict objectForKey:key];
			[curLayer setObject:obj forKey:key];
		}
		
		
		// Reset styles for each layer
		[self resetStyleContext];
		
		if([attrDict valueForKey:@"style"])
			[self setStyleContext:[attrDict valueForKey:@"style"]];
		
		if([attrDict valueForKey:@"transform"])
			[self applyTransformations:[attrDict valueForKey:@"transform"]];
	}
	
	
	// Path node
	// -------------------------------------------------------------------------
	if([elementName isEqualToString:@"path"]) {
		
		// For now, we'll ignore paths in definitions
		if(inDefSection)
			return;
		
		CGMutablePathRef path = CGPathCreateMutable();
		
		if([attrDict valueForKey:@"transform"])
			[self applyTransformations:[attrDict valueForKey:@"transform"]];
		
		// Create a scanner for parsing path data
		NSScanner *scanner = [NSScanner scannerWithString:[attrDict valueForKey:@"d"]];
		[scanner setCaseSensitive:YES];
		[scanner setCharactersToBeSkipped:[NSCharacterSet newlineCharacterSet]];
		
		CGPoint curPoint = CGPointMake(0,0);
		CGPoint curCtrlPoint1 = CGPointMake(-1,-1);
		CGPoint curCtrlPoint2 = CGPointMake(-1,-1);
		CGPoint curArcPoint = CGPointMake(-1,-1);
		CGPoint curArcRadius = CGPointMake(-1,-1);
		CGPoint firstPoint = CGPointMake(-1,-1);
		NSString *curCmdType = nil;
		
		NSCharacterSet *cmdCharSet = [NSCharacterSet characterSetWithCharactersInString:@"mMlLhHvVcCsSqQtTaAzZ"];
		NSCharacterSet *separatorSet = [NSCharacterSet characterSetWithCharactersInString:@" ,"];
		NSString *currentCommand = nil;
		NSString *currentParams = nil;
		while ([scanner scanCharactersFromSet:cmdCharSet intoString:&currentCommand]) {
			[scanner scanUpToCharactersFromSet:cmdCharSet intoString:&currentParams];
			
			NSArray *params = [currentParams componentsSeparatedByCharactersInSet:separatorSet];
			
			int paramCount = [params count];
			int mCount = 0;
			
			for (int prm_i = 0; prm_i < paramCount;) {
				if(![[params objectAtIndex:prm_i] isEqualToString:@""]) {
					
					BOOL firstVertex = (firstPoint.x == -1 && firstPoint.y == -1);
					
					// Move to absolute coord
					//-----------------------------------------
					if([currentCommand isEqualToString:@"M"]) {
						curCmdType = @"line";
						curPoint.x = [[params objectAtIndex:prm_i++] floatValue];
						curPoint.y = [[params objectAtIndex:prm_i++] floatValue];
						mCount++;
					}
					
					// Move to relative coord
					//-----------------------------------------
					if([currentCommand isEqualToString:@"m"]) {
						curCmdType = @"line";
						curPoint.x += [[params objectAtIndex:prm_i++] floatValue];
						
						if(firstVertex) {
							curPoint.y = [[params objectAtIndex:prm_i++] floatValue];
						} else {
							curPoint.y += [[params objectAtIndex:prm_i++] floatValue];
						}
						mCount++;
					}
					
					// Line to absolute coord
					//-----------------------------------------
					if([currentCommand isEqualToString:@"L"]) {
						curCmdType = @"line";
						mCount = 2;
						curPoint.x = [[params objectAtIndex:prm_i++] floatValue];
						curPoint.y = [[params objectAtIndex:prm_i++] floatValue];
					}
					
					// Line to relative coord
					//-----------------------------------------
					if([currentCommand isEqualToString:@"l"]) {
						curCmdType = @"line";
						mCount = 2;
						curPoint.x += [[params objectAtIndex:prm_i++] floatValue];
						if(firstVertex) {
							curPoint.y = [[params objectAtIndex:prm_i++] floatValue];
						} else {
							curPoint.y += [[params objectAtIndex:prm_i++] floatValue];
						}
					}
					
					// Horizontal line to absolute coord
					//-----------------------------------------
					if([currentCommand isEqualToString:@"H"]) {
						curCmdType = @"line";
						mCount = 2;
						curPoint.x = [[params objectAtIndex:prm_i++] floatValue];
					}
					
					// Horizontal line to relative coord
					//-----------------------------------------
					if([currentCommand isEqualToString:@"h"]) {
						curCmdType = @"line";
						mCount = 2;
						curPoint.x += [[params objectAtIndex:prm_i++] floatValue];
					}
					
					// Vertical line to absolute coord
					//-----------------------------------------
					if([currentCommand isEqualToString:@"V"]) {
						curCmdType = @"line";
						mCount = 2;
						curPoint.y = [[params objectAtIndex:prm_i++] floatValue];
					}
					
					// Vertical line to relative coord
					//-----------------------------------------
					if([currentCommand isEqualToString:@"v"]) {
						curCmdType = @"line";
						mCount = 2;
						curPoint.y += [[params objectAtIndex:prm_i++] floatValue];
					}
					
					// Curve to absolute coord
					//-----------------------------------------
					if([currentCommand isEqualToString:@"C"]) {
						curCmdType = @"curve";
						
						curCtrlPoint1.x = [[params objectAtIndex:prm_i++] floatValue];
						curCtrlPoint1.y = [[params objectAtIndex:prm_i++] floatValue];
						
						curCtrlPoint2.x = [[params objectAtIndex:prm_i++] floatValue];
						curCtrlPoint2.y = [[params objectAtIndex:prm_i++] floatValue];
						
						curPoint.x = [[params objectAtIndex:prm_i++] floatValue];
						curPoint.y = [[params objectAtIndex:prm_i++] floatValue];
					}
					
					// Curve to relative coord
					//-----------------------------------------
					if([currentCommand isEqualToString:@"c"]) {
						curCmdType = @"curve";
						
						curCtrlPoint1.x = curPoint.x + [[params objectAtIndex:prm_i++] floatValue];
						curCtrlPoint1.y = curPoint.y + [[params objectAtIndex:prm_i++] floatValue];
						
						curCtrlPoint2.x = curPoint.x + [[params objectAtIndex:prm_i++] floatValue];
						curCtrlPoint2.y = curPoint.y + [[params objectAtIndex:prm_i++] floatValue];
						
						curPoint.x += [[params objectAtIndex:prm_i++] floatValue];
						curPoint.y += [[params objectAtIndex:prm_i++] floatValue];
					}
					
					// Shorthand curve to absolute coord
					//-----------------------------------------
					if([currentCommand isEqualToString:@"S"]) {
						curCmdType = @"curve";
						
						if(curCtrlPoint2.x != -1 && curCtrlPoint2.y != -1) {
							curCtrlPoint1.x = curCtrlPoint2.x;
							curCtrlPoint1.y = curCtrlPoint2.y;
						} else {
							curCtrlPoint1.x = curPoint.x;
							curCtrlPoint1.y = curPoint.y;
						}
						
						curCtrlPoint2.x = [[params objectAtIndex:prm_i++] floatValue];
						curCtrlPoint2.y = [[params objectAtIndex:prm_i++] floatValue];
						
						curPoint.x = [[params objectAtIndex:prm_i++] floatValue];
						curPoint.y = [[params objectAtIndex:prm_i++] floatValue];
					}
					
					// Shorthand curve to relative coord
					//-----------------------------------------
					if([currentCommand isEqualToString:@"s"]) {
						curCmdType = @"curve";
						
						if(curCtrlPoint2.x != -1 && curCtrlPoint2.y != -1) {
							curCtrlPoint1.x = curPoint.x + curCtrlPoint2.x;
							curCtrlPoint1.y = curPoint.y + curCtrlPoint2.x;
						} else {
							curCtrlPoint1.x = curPoint.x;
							curCtrlPoint1.y = curPoint.y;
						}
						
						curCtrlPoint2.x = curPoint.x + [[params objectAtIndex:prm_i++] floatValue];
						curCtrlPoint2.y = curPoint.y + [[params objectAtIndex:prm_i++] floatValue];
						
						curPoint.x += [[params objectAtIndex:prm_i++] floatValue];
						curPoint.y += [[params objectAtIndex:prm_i++] floatValue];
					}
					
					// Absolute elliptical arc
					//-----------------------------------------
					if([currentCommand isEqualToString:@"A"]) {
						curArcRadius.x = [[params objectAtIndex:prm_i++] floatValue];
						curArcRadius.y = [[params objectAtIndex:prm_i++] floatValue];
						
						//Ignore x-axis-rotation
						prm_i++;;
						
						//Ignore large-arc-flag
						prm_i++;
						
						//Ignore sweep-flag
						prm_i++;
						
						curArcPoint.x = [[params objectAtIndex:prm_i++] floatValue];
						curArcPoint.y = [[params objectAtIndex:prm_i++] floatValue];
					}
					
					// Relative elliptical arc
					//-----------------------------------------
					if([currentCommand isEqualToString:@"a"]) {
						curCmdType = @"arc";
						curArcRadius.x += [[params objectAtIndex:prm_i++] floatValue];
						curArcRadius.y += [[params objectAtIndex:prm_i++] floatValue];
						
						//Ignore x-axis-rotation
						prm_i++;;
						
						//Ignore large-arc-flag
						prm_i++;
						
						//Ignore sweep-flag
						prm_i++;
						
						curArcPoint.x += [[params objectAtIndex:prm_i++] floatValue];
						curArcPoint.y += [[params objectAtIndex:prm_i++] floatValue];
					}
					
					
					// Not yet implemented commands
					//-----------------------------------------
					if([currentCommand isEqualToString:@"q"]
					|| [currentCommand isEqualToString:@"Q"]
					|| [currentCommand isEqualToString:@"t"]
					|| [currentCommand isEqualToString:@"T"]) {
						prm_i++;
					}
					
					// Set initial point
					if(firstVertex) {
						firstPoint = curPoint;
						CGPathMoveToPoint(path, NULL, firstPoint.x * scale, firstPoint.y * scale);
					}
					
					// Close path
					if([currentCommand isEqualToString:@"z"] || [currentCommand isEqualToString:@"Z"]) {
						CGPathCloseSubpath(path);
						curPoint = CGPointMake(-1, -1);
						firstPoint = CGPointMake(-1, -1);
						firstVertex = YES;
						prm_i++;
					}
					
					if(curCmdType) {
						if([curCmdType isEqualToString:@"line"]) {
							if(mCount>1) {
								CGPathAddLineToPoint(path, NULL, curPoint.x * scale, curPoint.y * scale);
							} else {
								CGPathMoveToPoint(path, NULL, curPoint.x * scale, curPoint.y * scale);
							}
						}
						
						if([curCmdType isEqualToString:@"curve"])
							CGPathAddCurveToPoint(path,NULL,curCtrlPoint1.x * scale, curCtrlPoint1.y * scale,
													  curCtrlPoint2.x * scale, curCtrlPoint2.y * scale,
													  curPoint.x * scale,curPoint.y * scale);
						
						if([curCmdType isEqualToString:@"arc"]) {
							// Ignore arcs for now
							//NSLog(@"[path appendBezierPathWithArcFromPoint:%f,%f toPoint:%f,%f radius:%f];", curPoint.x, curPoint.y, curArcPoint.x, curArcPoint.y, curArcRadius.x);
							//[path appendBezierPathWithArcFromPoint:curPoint toPoint:curArcPoint radius:curArcRadius.x];
						}
					}
				} else {
					prm_i++;
				}

			}
			
			currentParams = nil;
		}
		
		//CGContextClosePath(cgContext);
		[self drawPath:path withStyle:[attrDict valueForKey:@"style"]];
	}
	
	
	// Rect node
	// -------------------------------------------------------------------------
	if([elementName isEqualToString:@"rect"]) {
		float xPos = [[attrDict valueForKey:@"x"] floatValue];
		float yPos = [[attrDict valueForKey:@"y"] floatValue];
		float width = [[attrDict valueForKey:@"width"] floatValue];
		float height = [[attrDict valueForKey:@"height"] floatValue];
		float ry = [attrDict valueForKey:@"ry"]?[[attrDict valueForKey:@"ry"] floatValue]:-1.0;
		float rx = [attrDict valueForKey:@"rx"]?[[attrDict valueForKey:@"rx"] floatValue]:-1.0;
		
		if (ry==-1.0) ry = rx;
		if (rx==-1.0) rx = ry;
		
		CGMutablePathRef path = CGPathCreateMutable();
		CGPathAddRoundRect(path, CGRectMake(xPos * scale,yPos * scale,width * scale,height * scale), rx * scale);
		
		[self drawPath:path withStyle:[attrDict valueForKey:@"style"]];
	}
	
	[pool release];
}


// Element ended
// -----------------------------------------------------------------------------
- (void)parser:(NSXMLParser *)parser
 didEndElement:(NSString *)elementName
  namespaceURI:(NSString *)namespaceURI
 qualifiedName:(NSString *)qName
{
	if([elementName isEqualToString:@"svg"]) {
		[defDict release];
		delegate?[delegate svgRenderer:self didFinnishRenderingFile:svgFileName inCGContext:cgContext]:nil;
	}
	
	if([elementName isEqualToString:@"g"]) {
		// Set the coordinates back the way they were
		//if(cur)
		//[transform invert];
		//[transform concat];
	}
	
	if([elementName isEqualToString:@"defs"]) {
		inDefSection = NO;
	}

	if([elementName isEqualToString:@"path"]) {
	}
	
	if([elementName isEqualToString:@"pattern"]) {
		if([curPat objectForKey:@"id"])
		[defDict setObject:curPat forKey:[curPat objectForKey:@"id"]];
	}
	
	if([elementName isEqualToString:@"linearGradient"]) {
		if([curGradient objectForKey:@"id"])
		[defDict setObject:curGradient forKey:[curGradient objectForKey:@"id"]];
	}
	
	if([elementName isEqualToString:@"radialGradient"]) {
		if([curGradient objectForKey:@"id"])
		[defDict setObject:curGradient forKey:[curGradient objectForKey:@"id"]];
	}
}


// Draw a path based on style information
// -----------------------------------------------------------------------------
- (void)drawPath:(CGMutablePathRef)path withStyle:(NSString *)style
{		
	CGContextSaveGState(cgContext);
	
	if(style)
		[self setStyleContext:style];
	
	if(doFill) {
		if ([fillType isEqualToString:@"solid"]) {
			
			CGContextSetRGBFillColor(cgContext, fillColor[0], fillColor[1], fillColor[2], fillColor[3]);
			
		} else if([fillType isEqualToString:@"pattern"]) {
			
			CGColorSpaceRef myColorSpace = CGColorSpaceCreatePattern(NULL);
			CGContextSetFillColorSpace(cgContext, myColorSpace);
			CGColorSpaceRelease(myColorSpace);
			
			float alpha = fillColor[3];
			CGContextSetFillPattern (cgContext,
									 fillPattern,
									 &alpha);
			
		} else if([fillType isEqualToString:@"linearGradient"]) {
			
			doFill = NO;
			CGContextAddPath(cgContext, path);
			CGContextSaveGState(cgContext);
			CGContextClip(cgContext);
			CGContextDrawLinearGradient(cgContext, fillGradient, fillGradientPoints[0], fillGradientPoints[1], 3);
			CGContextRestoreGState(cgContext);
			
		} else if([fillType isEqualToString:@"radialGradient"]) {
			
			doFill = NO;
			CGContextAddPath(cgContext, path);
			CGContextSaveGState(cgContext);
			CGContextClip(cgContext);
			CGContextDrawRadialGradient(cgContext, fillGradient, fillGradientCenterPoint, 0, fillGradientCenterPoint, fillGradientPoints[0].y, 3);
			CGContextRestoreGState(cgContext);
			
		}
	}
	
	// Do the drawing
	// -------------------------------------------------------------------------
	if(doStroke) {
		CGFloat red   = ((strokeColor & 0xFF0000) >> 16) / 255.0f;
		CGFloat green = ((strokeColor & 0x00FF00) >>  8) / 255.0f;
		CGFloat blue  =  (strokeColor & 0x0000FF) / 255.0f;
		CGContextSetLineWidth(cgContext, strokeWidth);
		CGContextSetLineCap(cgContext, lineCapStyle);
		CGContextSetLineJoin(cgContext, lineJoinStyle);
		CGContextSetMiterLimit(cgContext, miterLimit);
		CGContextSetRGBStrokeColor(cgContext, red, green, blue, strokeOpacity);
		
	}
	
	if(doFill || doStroke)
		CGContextAddPath(cgContext, path);
	
	if(doFill && doStroke)
		CGContextDrawPath(cgContext, kCGPathFillStroke);
	else if(doFill)
		CGContextFillPath(cgContext);
	else if(doStroke)
		CGContextStrokePath(cgContext);
	
	CGContextRestoreGState(cgContext);
	
}

- (void)setStyleContext:(NSString *)style
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
				NSScanner *hexScanner = [NSScanner scannerWithString:
										 [attrValue stringByReplacingOccurrencesOfString:@"#" withString:@"0x"]];
				[hexScanner setCharactersToBeSkipped:[NSCharacterSet symbolCharacterSet]]; 
				unsigned int color;
				[hexScanner scanHexInt:&color];
				fillColor[0] = ((color & 0xFF0000) >> 16) / 255.0f;
				fillColor[1] = ((color & 0x00FF00) >>  8) / 255.0f;
				fillColor[2] =  (color & 0x0000FF) / 255.0f;
				
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
					NSDictionary *def = [self getCompleteDefinitionFromID:url];
					if([def objectForKey:@"images"] && [[def objectForKey:@"images"] count] > 0) {
						
						// Load bitmap pattern
						fillType = [def objectForKey:@"type"];
						NSString *imgString = [[[def objectForKey:@"images"] objectAtIndex:0] objectForKey:@"xlink:href"];
						NSArray *mimeAndData = [imgString componentsSeparatedByString:@","];
						NSData *imgData = [[NSData dataWithBase64EncodedString:[mimeAndData objectAtIndex:1]] retain];
						CGDataProviderRef provider = CGDataProviderCreateWithCFData((CFDataRef)imgData);
						
						CGImageRef patternImage;
						if([[mimeAndData objectAtIndex:0] isEqualToString:@"data:image/jpeg;base64"])
							patternImage = CGImageCreateWithJPEGDataProvider(provider, NULL, true, kCGRenderingIntentDefault);
						else if([[mimeAndData objectAtIndex:0] isEqualToString:@"data:image/png;base64"])
							patternImage = CGImageCreateWithPNGDataProvider(provider, NULL, true, kCGRenderingIntentDefault);
						
						CGImageRetain(patternImage);
						
						desc.imgRef = patternImage;
						desc.rect = CGRectMake(0, 0, 
											   [[[[def objectForKey:@"images"] objectAtIndex:0] objectForKey:@"width"] floatValue], 
											   [[[[def objectForKey:@"images"] objectAtIndex:0] objectForKey:@"height"] floatValue]);
						CGPatternCallbacks callbacks = { 0, &drawImagePattern, NULL };
						
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
							fillGradientPoints[0] = CGPointMake([[def objectForKey:@"x1"] floatValue] * scale,[[def objectForKey:@"y1"] floatValue] * scale);
							fillGradientPoints[1] = CGPointMake([[def objectForKey:@"x2"] floatValue] * scale,[[def objectForKey:@"y2"] floatValue] * scale);
							//fillGradientAngle = (((atan2(([[def objectForKey:@"x1"] floatValue] - [[def objectForKey:@"x2"] floatValue]),
							//											([[def objectForKey:@"y1"] floatValue] - [[def objectForKey:@"y2"] floatValue])))*180)/M_PI)+90;
						} if([def objectForKey:@"cx"]) {
							fillGradientCenterPoint.x = [[def objectForKey:@"cx"] floatValue] * scale;
							fillGradientCenterPoint.y = [[def objectForKey:@"cy"] floatValue] * scale;
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
			[floatScanner scanFloat:&fillColor[3]];
		}
		
		// --------------------- STROKE
		if([attrName isEqualToString:@"stroke"]) {
			if(![attrValue isEqualToString:@"none"]) {
				doStroke = YES;
				NSScanner *hexScanner = [NSScanner scannerWithString:
										 [attrValue stringByReplacingOccurrencesOfString:@"#" withString:@"0x"]];
				[hexScanner setCharactersToBeSkipped:[NSCharacterSet symbolCharacterSet]]; 
				[hexScanner scanHexInt:&strokeColor];
				strokeWidth = 1 * scale;
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
			strokeWidth *= scale;
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
		
		[cssScanner scanString:@";" intoString:nil];
	}
	[pool release];
}

- (void)applyTransformations:(NSString *)transformations
{
	CGContextConcatCTM(cgContext,CGAffineTransformInvert(transform));
	
	// Reset transformation matrix
	transform = CGAffineTransformIdentity;
	
	NSScanner *scanner = [NSScanner scannerWithString:transformations];
	[scanner setCaseSensitive:YES];
	[scanner setCharactersToBeSkipped:[NSCharacterSet newlineCharacterSet]];
	
	NSString *value;
	
	// Translate
	[scanner scanString:@"translate(" intoString:nil];
	[scanner scanUpToString:@")" intoString:&value];
	
	NSArray *values = [value componentsSeparatedByString:@","];
	
	if([values count] == 2)
		transform = CGAffineTransformTranslate (transform,
									[[values objectAtIndex:0] floatValue] * scale,
									[[values objectAtIndex:1] floatValue] * scale);
	
	// Rotate
	value = [NSString string];
	[scanner initWithString:transformations];
	[scanner scanString:@"rotate(" intoString:nil];
	[scanner scanUpToString:@")" intoString:&value];
	
	if(value)
		transform = CGAffineTransformRotate(transform, [value floatValue]);
	
	// Matrix
	value = [NSString string];
	[scanner initWithString:transformations];
	[scanner scanString:@"matrix(" intoString:nil];
	[scanner scanUpToString:@")" intoString:&value];
	
	values = [value componentsSeparatedByString:@","];
	
	if([values count] == 6) {
		CGAffineTransform matrixTransform = CGAffineTransformMake ([[values objectAtIndex:0] floatValue],
																   [[values objectAtIndex:1] floatValue],
																   [[values objectAtIndex:2] floatValue],
																   [[values objectAtIndex:3] floatValue],
																   [[values objectAtIndex:4] floatValue],
																   [[values objectAtIndex:5] floatValue]);
		transform = CGAffineTransformConcat(transform, matrixTransform);
	}
	
	// Apply to graphics context
	CGContextConcatCTM(cgContext,transform);
}

- (NSDictionary *)getCompleteDefinitionFromID:(NSString *)identifier
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

- (CGContextRef)createBitmapContext
{
	CGContextRef ctx = CGBitmapContextCreate(NULL, (int)documentSize.width, (int)documentSize.height, 8, (int)documentSize.width*4, CGColorSpaceCreateDeviceRGB(), kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
	return ctx;
}

void drawImagePattern(void * fillPatDescriptor, CGContextRef context)
{
	FillPatternDescriptor *patDesc;
	patDesc = (FillPatternDescriptor *)fillPatDescriptor;
	NSLog(@"%d", patDesc->imgRef);
	CGContextDrawImage(context, patDesc->rect, patDesc->imgRef);
	CGImageRelease(patDesc->imgRef);
}

void CGPathAddRoundRect(CGMutablePathRef path, CGRect rect, float radius)
{
	CGPathMoveToPoint(path, NULL, rect.origin.x, rect.origin.y + radius);
	
	CGPathAddLineToPoint(path, NULL, rect.origin.x, rect.origin.y + rect.size.height - radius);
	CGPathAddArc(path, NULL, rect.origin.x + radius, rect.origin.y + rect.size.height - radius, 
					radius, M_PI / 1, M_PI / 2, 1);
	
	CGPathAddLineToPoint(path, NULL, rect.origin.x + rect.size.width - radius, 
							rect.origin.y + rect.size.height);
	CGPathAddArc(path, NULL, rect.origin.x + rect.size.width - radius, 
					rect.origin.y + rect.size.height - radius, radius, M_PI / 2, 0.0f, 1);
	
	CGPathAddLineToPoint(path, NULL, rect.origin.x + rect.size.width, rect.origin.y + radius);
	CGPathAddArc(path, NULL, rect.origin.x + rect.size.width - radius, rect.origin.y + radius, 
					radius, 0.0f, -M_PI / 2, 1);
	
	CGPathAddLineToPoint(path, NULL, rect.origin.x + radius, rect.origin.y);
	CGPathAddArc(path, NULL, rect.origin.x + radius, rect.origin.y + radius, radius, 
					-M_PI / 2, M_PI, 1);
}

- (void)dealloc
{
	[defDict release];
	[curPat release];
	[curGradient release];
	[curFilter release];
	[xmlParser release];
	
	[super dealloc];
}

@end
