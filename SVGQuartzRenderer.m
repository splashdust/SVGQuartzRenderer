//
//  SVGWorldParser.m
//  StuntBike X
//
//  Created by Joacim Magnusson on 2010-09-20.
//  Copyright 2010 Joacim Magnusson. All rights reserved.
//

#import "SVGQuartzRenderer.h"

@interface SVGQuartzRenderer (hidden)

	- (void)setStyleContext:(NSString *)style;
	- (void)drawPath:(NSBezierPath *)path withStyle:(NSString *)style;

@end

@implementation SVGQuartzRenderer

NSXMLParser* xmlParser;
NSAffineTransform *transform;
NSAffineTransform *identity;
CGSize documentSize;
NSImage *canvas;
NSView *view;
NSMutableDictionary *defDict;

NSMutableDictionary *curPat;
NSMutableDictionary *curLinGrad;
NSMutableDictionary *curRadGrad;
NSMutableDictionary *curFilter;

// Variables for storing style data
// -------------------------------------------------------------------------
BOOL doFill;
unsigned int fillColor;
float fillOpacity;
BOOL doStroke = NO;
unsigned int strokeColor = 0;
float strokeWidth = 1.0;
float strokeOpacity;
NSLineJoinStyle lineJoinStyle;
NSLineCapStyle lineCapStyle;
float miterLimit;
// -------------------------------------------------------------------------

- (void)resetStyleContext
{
	doFill = YES;
	fillColor = 0;
	fillOpacity = 1.0;
	//doStroke = NO;
	strokeColor = 0;
	strokeWidth = 1.0;
	strokeOpacity = 1.0;
	lineJoinStyle = NSMiterLineJoinStyle;
	lineCapStyle = NSButtLineCapStyle;
	miterLimit = 4;
}

- (NSImage *)imageFromSVGFile:(NSString *)file view:(NSView *)aView
{
	NSURL* xmlURL = [NSURL fileURLWithPath:file];
	xmlParser = [[NSXMLParser alloc] initWithContentsOfURL:xmlURL];
	
	canvas = [[NSImage alloc] init];
	view = aView;
	
	transform = [[NSAffineTransform transform] retain];
	identity = [[NSAffineTransform transform] retain];
	
	[xmlParser setDelegate:self];
	[xmlParser setShouldResolveExternalEntities:YES];
	[xmlParser parse];
		
	return canvas;
}


// Element began
// -----------------------------------------------------------------------------
- (void)parser:(NSXMLParser *)parser
didStartElement:(NSString *)elementName 
  namespaceURI:(NSString *)namespaceURI
 qualifiedName:(NSString *)qualifiedName
	attributes:(NSDictionary *)attrDict
{
	// Path used for rendering
	NSBezierPath * path = [NSBezierPath bezierPath];
	
	// Top level SVG node
	// -------------------------------------------------------------------------
	if([elementName isEqualToString:@"svg"]) {
		documentSize = CGSizeMake([[attrDict valueForKey:@"width"] floatValue],
							   [[attrDict valueForKey:@"height"] floatValue]);
		
		[view setFrame:NSMakeRect(0, 0, documentSize.width, documentSize.height)];
		
		doStroke = NO;
	}
	
	// Definitions
	// -------------------------------------------------------------------------
	if([elementName isEqualToString:@"defs"]) {
		defDict = [[NSMutableDictionary alloc] init];
	}
	
		if([elementName isEqualToString:@"pattern"]) {
			curPat = [[NSMutableDictionary alloc] init];
		}
			if([elementName isEqualToString:@"image"]) {
				
			}
		
		if([elementName isEqualToString:@"linearGradient"]) {
			curLinGrad = [[NSMutableDictionary alloc] init];
		}
			if([elementName isEqualToString:@"stop"]) {
				
			}
		
		if([elementName isEqualToString:@"radialGradient"]) {
			curRadGrad = [[NSMutableDictionary alloc] init];
		}
	
		if([elementName isEqualToString:@"filter"]) {
			curFilter = [[NSMutableDictionary alloc] init];
		}
			if([elementName isEqualToString:@"feGaussianBlur"]) {
				
			}
	
	// Group node
	// -------------------------------------------------------------------------
	if([elementName isEqualToString:@"g"]) {
		
		[self resetStyleContext];
		
		if([attrDict valueForKey:@"style"])
			[self setStyleContext:[attrDict valueForKey:@"style"]];
		
		// Reset transformation matrix
		[transform initWithTransform:identity];
		
		// Look for and apply transformations to the current layer canvas
		NSString *transformAttribute = [attrDict valueForKey:@"transform"];
		if(transformAttribute != nil) {
			NSScanner *scanner = [NSScanner scannerWithString:[attrDict valueForKey:@"transform"]];
			[scanner setCaseSensitive:YES];
			[scanner setCharactersToBeSkipped:[NSCharacterSet newlineCharacterSet]];
			
			NSString *value;
			
			// Translate
			[scanner scanString:@"translate(" intoString:nil];
			[scanner scanUpToString:@")" intoString:&value];
			
			NSArray *values = [value componentsSeparatedByString:@","];
			
			if([values count] == 2)
				[transform translateXBy:[[values objectAtIndex:0] floatValue] yBy:[[values objectAtIndex:1] floatValue]];
			
			// Rotate
			value = nil;
			[scanner scanString:@"rotate(" intoString:nil];
			[scanner scanUpToString:@")" intoString:&value];
			
			if(value)
				[transform rotateByDegrees:[value floatValue]];
		}
		
		// Apply to graphics context
		[transform concat];
	}
	
	
	// Path node
	// -------------------------------------------------------------------------
	if([elementName isEqualToString:@"path"]) {
		//[canvas lockFocus];
		
		// Create a scanner for parsing path data
		NSScanner *scanner = [NSScanner scannerWithString:[attrDict valueForKey:@"d"]];
		[scanner setCaseSensitive:YES];
		[scanner setCharactersToBeSkipped:[NSCharacterSet newlineCharacterSet]];
		
		CGPoint curPoint = CGPointMake(0,0);
		CGPoint curCtrlPoint1 = CGPointMake(-1,-1);
		CGPoint curCtrlPoint2 = CGPointMake(-1,-1);
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
			NSAutoreleasePool *pool =  [[NSAutoreleasePool alloc] init];
			
			for (int prm_i = 0; prm_i < paramCount;) {
				if(![[params objectAtIndex:prm_i] isEqualToString:@""]) {
					
					BOOL firstVertex = (firstPoint.x == -1 && firstPoint.y == -1);
					
					// Move to absolute coord
					//-----------------------------------------
					if([currentCommand isEqualToString:@"M"]) {
						curCmdType = @"line";
						curPoint.x = [[params objectAtIndex:prm_i++] floatValue];
						curPoint.y = [[params objectAtIndex:prm_i++] floatValue];
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
					}
					
					// Line to absolute coord
					//-----------------------------------------
					if([currentCommand isEqualToString:@"L"]) {
						curCmdType = @"line";
						curPoint.x = [[params objectAtIndex:prm_i++] floatValue];
						curPoint.y = [[params objectAtIndex:prm_i++] floatValue];
					}
					
					// Line to relative coord
					//-----------------------------------------
					if([currentCommand isEqualToString:@"l"]) {
						curCmdType = @"line";
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
						curPoint.x = [[params objectAtIndex:prm_i++] floatValue];
					}
					
					// Horizontal line to relative coord
					//-----------------------------------------
					if([currentCommand isEqualToString:@"h"]) {
						curCmdType = @"line";
						curPoint.x += [[params objectAtIndex:prm_i++] floatValue];
					}
					
					// Vertical line to absolute coord
					//-----------------------------------------
					if([currentCommand isEqualToString:@"V"]) {
						curCmdType = @"line";
						curPoint.y = [[params objectAtIndex:prm_i++] floatValue];
					}
					
					// Vertical line to relative coord
					//-----------------------------------------
					if([currentCommand isEqualToString:@"v"]) {
						curCmdType = @"line";
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
					
					if(firstVertex) {
						firstPoint = curPoint;
						[path moveToPoint: firstPoint];
					}
					
					if(curCmdType) {
						if([curCmdType isEqualToString:@"line"]) {
							[path lineToPoint: curPoint];
						}
						
						if([curCmdType isEqualToString:@"curve"])
							[path curveToPoint:curPoint controlPoint1:curCtrlPoint1 controlPoint2:curCtrlPoint2];
					}
				} else {
					prm_i++;
				}

			}
			
			[pool release];
			
			// Close path
			if([currentCommand isEqualToString:@"z"] || [currentCommand isEqualToString:@"Z"]) {

			}
			
			
			currentParams = nil;
		}
		
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
		
		[path appendBezierPathWithRoundedRect:CGRectMake(xPos,yPos,width,height)
									  xRadius:rx
									  yRadius:ry];
		
		[self drawPath:path withStyle:[attrDict valueForKey:@"style"]];
	}
	
	//[canvas unlockFocus];
}


// Element ended
// -----------------------------------------------------------------------------
- (void)parser:(NSXMLParser *)parser
 didEndElement:(NSString *)elementName
  namespaceURI:(NSString *)namespaceURI
 qualifiedName:(NSString *)qName
{
	if([elementName isEqualToString:@"g"]) {
		// Set the coordinates back the way they were
		[transform invert];
		[transform concat];
	}
}


// Draw a path based on style information
// -----------------------------------------------------------------------------
- (void)drawPath:(NSBezierPath *)path withStyle:(NSString *)style
{		
	if(style)
		[self setStyleContext:style];
	
	// Do the drawing
	// -------------------------------------------------------------------------
	if(doFill) {
		CGFloat red   = ((fillColor & 0xFF0000) >> 16) / 255.0f;
		CGFloat green = ((fillColor & 0x00FF00) >>  8) / 255.0f;
		CGFloat blue  =  (fillColor & 0x0000FF) / 255.0f;
		[[NSColor colorWithDeviceRed:red green:green blue:blue alpha:fillOpacity] set];
		[path fill];
	}
	
	
	if(doStroke) {
		CGFloat red   = ((strokeColor & 0xFF0000) >> 16) / 255.0f;
		CGFloat green = ((strokeColor & 0x00FF00) >>  8) / 255.0f;
		CGFloat blue  =  (strokeColor & 0x0000FF) / 255.0f;
		[[NSColor colorWithDeviceRed:red green:green blue:blue alpha:strokeOpacity] set];
		[path setLineWidth:strokeWidth];
		[path setLineCapStyle:lineCapStyle];
		[path setLineJoinStyle:lineJoinStyle];
		[path setMiterLimit:miterLimit];
		[path stroke];
	}
}

- (void)setStyleContext:(NSString *)style
{
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
				NSScanner *hexScanner = [NSScanner scannerWithString:
										 [attrValue stringByReplacingOccurrencesOfString:@"#" withString:@"0x"]];
				[hexScanner setCharactersToBeSkipped:[NSCharacterSet symbolCharacterSet]]; 
				[hexScanner scanHexInt:&fillColor];
			} else {
				doFill = NO;
			}

		}
		
		// --------------------- FILL-OPACITY
		if([attrName isEqualToString:@"fill-opacity"]) {
			NSScanner *floatScanner = [NSScanner scannerWithString:attrValue];
			[floatScanner scanFloat:&fillOpacity];
		}
		
		// --------------------- STROKE
		if([attrName isEqualToString:@"stroke"]) {
			if(![attrValue isEqualToString:@"none"]) {
				doStroke = YES;
				NSScanner *hexScanner = [NSScanner scannerWithString:
										 [attrValue stringByReplacingOccurrencesOfString:@"#" withString:@"0x"]];
				[hexScanner setCharactersToBeSkipped:[NSCharacterSet symbolCharacterSet]]; 
				[hexScanner scanHexInt:&strokeColor];
				NSLog(@"%d", strokeColor);
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
				lineCapStyle = NSButtLineCapStyle;
			
			if([lineCapValue isEqualToString:@"round"])
				lineCapStyle = NSRoundLineCapStyle;
			
			if([lineCapValue isEqualToString:@"square"])
				lineCapStyle = NSSquareLineCapStyle;
		}
		
		// --------------------- STROKE-LINEJOIN
		if([attrName isEqualToString:@"stroke-linejoin"]) {
			NSScanner *stringScanner = [NSScanner scannerWithString:attrValue];
			NSString *lineCapValue;
			[stringScanner scanUpToString:@";" intoString:&lineCapValue];
			
			if([lineCapValue isEqualToString:@"miter"])
				lineJoinStyle = NSMiterLineJoinStyle;
			
			if([lineCapValue isEqualToString:@"round"])
				lineJoinStyle = NSRoundLineJoinStyle;
			
			if([lineCapValue isEqualToString:@"bevel"])
				lineJoinStyle = NSBevelLineJoinStyle;
		}
		
		// --------------------- STROKE-MITERLIMIT
		if([attrName isEqualToString:@"stroke-miterlimit"]) {
			NSScanner *floatScanner = [NSScanner scannerWithString:attrValue];
			[floatScanner scanFloat:&miterLimit];
		}
		
		[cssScanner scanString:@";" intoString:nil];
	}
}

- (void)dealloc
{
	[transform release];
	[identity release];
	[defDict release];
	[curPat release];
	[curLinGrad release];
	[curRadGrad release];
	[curFilter release];
	
	[super dealloc];
}

@end
