//
//  SVGWorldParser.m
//  StuntBike X
//
//  Created by Joacim Magnusson on 2010-09-20.
//  Copyright 2010 Joacim Magnusson. All rights reserved.
//

#import "SVGQuartzRenderer.h"

@interface SVGQuartzRenderer (hidden)

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
	
	// Graphics layer node
	// -------------------------------------------------------------------------
	if([elementName isEqualToString:@"g"]) {
		
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
		CGPoint curCtrlPoint1 = CGPointMake(0, 0);
		CGPoint curCtrlPoint2 = CGPointMake(0, 0);
		CGPoint firstPoint = CGPointMake(-1,-1);
		NSString *curCmdType = nil;
		
		NSCharacterSet *cmdCharSet = [NSCharacterSet characterSetWithCharactersInString:@"mMlLhHvVcCsSqQtTaAzZ"];
		NSString *currentCommand = nil;
		NSString *currentParams = nil;
		while ([scanner scanCharactersFromSet:cmdCharSet intoString:&currentCommand]) {
			[scanner scanUpToCharactersFromSet:cmdCharSet intoString:&currentParams];
			
			NSArray *params = [currentParams componentsSeparatedByString:@" "];
			
			int paramCount = [params count];
			NSAutoreleasePool *pool =  [[NSAutoreleasePool alloc] init];
			
			for (int prm_i = 0; prm_i < paramCount; prm_i++) {
				
				NSArray *param = [[params objectAtIndex:prm_i] componentsSeparatedByString:@","];
				
				for (int prm_ii = 0; prm_ii < [param count]; prm_ii++) {
					if(![[param objectAtIndex:prm_ii] isEqualToString:@""]) {
						
						BOOL firstVertex = (firstPoint.x == -1 && firstPoint.y == -1);
						
						// Move to absolute coord
						//-----------------------------------------
						if([currentCommand isEqualToString:@"M"]) {
							curCmdType = @"line";
							curPoint.x = [[param objectAtIndex:0] floatValue];
							curPoint.y = [[param objectAtIndex:1] floatValue];
						}
						
						// Move to relative coord
						//-----------------------------------------
						if([currentCommand isEqualToString:@"m"]) {
							curCmdType = @"line";
							curPoint.x += [[param objectAtIndex:0] floatValue];
							
							if(firstVertex) {
								curPoint.y = [[param objectAtIndex:1] floatValue];
							} else {
								curPoint.y += [[param objectAtIndex:1] floatValue];
							}
						}
						
						// Line to absolute coord
						//-----------------------------------------
						if([currentCommand isEqualToString:@"L"]) {
							curCmdType = @"line";
							curPoint.x = [[param objectAtIndex:0] floatValue];
							curPoint.y = [[param objectAtIndex:1] floatValue];
						}
						
						// Line to relative coord
						//-----------------------------------------
						if([currentCommand isEqualToString:@"l"]) {
							curCmdType = @"line";
							curPoint.x += [[param objectAtIndex:0] floatValue];
							curPoint.y += [[param objectAtIndex:1] floatValue];
						}
						
						// Horizontal line to absolute coord
						//-----------------------------------------
						if([currentCommand isEqualToString:@"H"]) {
							curCmdType = @"line";
							curPoint.x = [[param objectAtIndex:0] floatValue];
						}
						
						// Horizontal line to relative coord
						//-----------------------------------------
						if([currentCommand isEqualToString:@"h"]) {
							curCmdType = @"line";
							curPoint.x += [[param objectAtIndex:0] floatValue];
						}
						
						// Vertical line to absolute coord
						//-----------------------------------------
						if([currentCommand isEqualToString:@"V"]) {
							curCmdType = @"line";
							curPoint.y = [[param objectAtIndex:0] floatValue];
						}
						
						// Vertical line to relative coord
						//-----------------------------------------
						if([currentCommand isEqualToString:@"v"]) {
							curCmdType = @"line";
							curPoint.y += [[param objectAtIndex:0] floatValue];
						}
						
						// Curve to absolute coord
						//-----------------------------------------
						if([currentCommand isEqualToString:@"C"]) {
							curCmdType = @"curve";
							
							curCtrlPoint1.x = [[param objectAtIndex:0] floatValue];
							curCtrlPoint1.y = [[param objectAtIndex:1] floatValue];
							
							prm_i++;
							param = [[params objectAtIndex:prm_i] componentsSeparatedByString:@","];
							curCtrlPoint2.x = [[param objectAtIndex:0] floatValue];
							curCtrlPoint2.y = [[param objectAtIndex:1] floatValue];
							
							prm_i++;
							param = [[params objectAtIndex:prm_i] componentsSeparatedByString:@","];
							curPoint.x = [[param objectAtIndex:0] floatValue];
							curPoint.y = [[param objectAtIndex:1] floatValue];
						}
						
						// Curve to relative coord
						//-----------------------------------------
						if([currentCommand isEqualToString:@"c"]) {
							curCmdType = @"curve";
							
							curCtrlPoint1.x = curPoint.x + [[param objectAtIndex:0] floatValue];
							curCtrlPoint1.y = curPoint.y + [[param objectAtIndex:1] floatValue];
							
							prm_i++;
							param = [[params objectAtIndex:prm_i] componentsSeparatedByString:@","];
							curCtrlPoint2.x = curPoint.x + [[param objectAtIndex:0] floatValue];
							curCtrlPoint2.y = curPoint.y + [[param objectAtIndex:1] floatValue];
							
							prm_i++;
							param = [[params objectAtIndex:prm_i] componentsSeparatedByString:@","];
							curPoint.x += [[param objectAtIndex:0] floatValue];
							curPoint.y += [[param objectAtIndex:1] floatValue];
						}
						
						if(firstVertex) {
							firstPoint = curPoint;
							[path moveToPoint: firstPoint];
						}
						
						if(curCmdType) {
							if([curCmdType isEqualToString:@"line"])
								[path lineToPoint: curPoint];
							
							if([curCmdType isEqualToString:@"curve"])
								[path curveToPoint:curPoint controlPoint1:curCtrlPoint1 controlPoint2:curCtrlPoint2];
						}
						
						break;
					}
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
	// Variables for storing style data
	// -------------------------------------------------------------------------
	BOOL doFill = NO;
	unsigned int fillColor = 0;
	float fillOpacity = 1.0;
	
	BOOL doStroke = NO;
	unsigned int strokeColor = 0;
	float strokeWidth = 1.0;
	float strokeOpacity = 1.0;
	NSLineJoinStyle lineJoinStyle = NSButtLineCapStyle;
	NSLineCapStyle lineCapStyle = NSButtLineCapStyle;
	float miterLimit = 4;
	// -------------------------------------------------------------------------
	
	
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
