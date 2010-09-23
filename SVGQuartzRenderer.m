//
//  SVGWorldParser.m
//  StuntBike X
//
//  Created by Joacim Magnusson on 2010-09-20.
//  Copyright 2010 Joacim Magnusson. All rights reserved.
//

#import "SVGQuartzRenderer.h"


#define UIColorFromRGB(rgbValue) [UIColor \
colorWithRed:((float)((rgbValue &amp; 0xFF0000) &gt;&gt; 16))/255.0 \
green:((float)((rgbValue &amp; 0xFF00) &gt;&gt; 8))/255.0 \
blue:((float)(rgbValue &amp; 0xFF))/255.0 alpha:1.0]

@implementation SVGQuartzRenderer

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

- (void)parser:(NSXMLParser *)parser
didStartElement:(NSString *)elementName 
  namespaceURI:(NSString *)namespaceURI
 qualifiedName:(NSString *)qualifiedName
	attributes:(NSDictionary *)attributeDict
{
	
	if([elementName isEqualToString:@"svg"]) {
		documentSize = CGSizeMake([[attributeDict valueForKey:@"width"] floatValue],
							   [[attributeDict valueForKey:@"height"] floatValue]);
		
		[view setFrame:NSMakeRect(0, 0, documentSize.width, documentSize.height)];
	}
	
	if([elementName isEqualToString:@"g"]) {
		
		// Reset transformation matrix
		[transform initWithTransform:identity];
		
		// Look for and apply transformations
		NSString *transformAttribute = [attributeDict valueForKey:@"transform"];
		if(transformAttribute != nil) {
			NSScanner *scanner = [NSScanner scannerWithString:[attributeDict valueForKey:@"transform"]];
			[scanner setCaseSensitive:YES];
			[scanner setCharactersToBeSkipped:[NSCharacterSet newlineCharacterSet]];
			
			NSString *tValue;
			
			[scanner scanString:@"translate(" intoString:nil];
			[scanner scanUpToString:@")" intoString:&tValue];
			
			NSArray *tValues = [tValue componentsSeparatedByString:@","];
			
			if([tValues count] == 2) {
				// Translate
				[transform translateXBy:[[tValues objectAtIndex:0] floatValue] yBy:[[tValues objectAtIndex:1] floatValue]];
			}
		}
		
		//[transform rotateByDegrees:client.rotation];
		
		// Apply to graphics context
		[transform concat];
	}
	
	if([elementName isEqualToString:@"path"]) {
		//[canvas lockFocus];
		
		// Create a scanner for parsing path data
		NSScanner *scanner = [NSScanner scannerWithString:[attributeDict valueForKey:@"d"]];
		[scanner setCaseSensitive:YES];
		[scanner setCharactersToBeSkipped:[NSCharacterSet newlineCharacterSet]];
		
		NSBezierPath * path = [NSBezierPath bezierPath];
		CGPoint curPoint = CGPointMake(0,0);
		CGPoint firstPoint = CGPointMake(-1,-1);
		
		NSString *currentCommand = nil;
		NSString *currentParams = nil;
		while ([scanner scanCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@"mMcCsSqQtTaAzZlLhHvV"] intoString:&currentCommand]) {
			[scanner scanUpToCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@"mMcCsSqQtTaAzZlLhHvV"] intoString:&currentParams];
			
			NSArray *params = [currentParams componentsSeparatedByString:@" "];
			
			int paramCount = [params count];
			NSAutoreleasePool *pool =  [[NSAutoreleasePool alloc] init];
			
			for (int prm_i = 0; prm_i < paramCount; prm_i++) {
				
				NSArray *param = [[params objectAtIndex:prm_i] componentsSeparatedByString:@","];
				
				for (int prm_ii = 0; prm_ii < [param count]; prm_ii++) {
					if(![[param objectAtIndex:prm_ii] isEqualToString:@""]) {
						
						BOOL firstVertex = (firstPoint.x == -1 && firstPoint.y == -1);
						
						// Move to absolute coord
						if([currentCommand isEqualToString:@"M"]) {
							curPoint.x = [[param objectAtIndex:0] floatValue];
							curPoint.y = documentSize.height-[[param objectAtIndex:1] floatValue];
						}
						
						// Move to relative coord
						if([currentCommand isEqualToString:@"m"]) {
							curPoint.x += [[param objectAtIndex:0] floatValue];
							
							if(firstVertex) {
								curPoint.y = documentSize.height-[[param objectAtIndex:1] floatValue];
							} else {
								curPoint.y += -[[param objectAtIndex:1] floatValue];
							}
						}
						
						// Line to absolute coord
						if([currentCommand isEqualToString:@"L"]) {
							curPoint.x = [[param objectAtIndex:0] floatValue];
							curPoint.y = documentSize.height-[[param objectAtIndex:1] floatValue];
						}
						
						// line to relative coord
						if([currentCommand isEqualToString:@"l"]) {
							curPoint.x += [[param objectAtIndex:0] floatValue];
							curPoint.y += -[[param objectAtIndex:1] floatValue];
						}
						
						if(firstVertex) {
							firstPoint = curPoint;
							[path moveToPoint: firstPoint];
						}
						
						[path lineToPoint: curPoint];
						
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
		
		// Create a scanner for parsing style data
		NSScanner *cssScanner = [NSScanner scannerWithString:[attributeDict valueForKey:@"style"]];
		[cssScanner setCaseSensitive:YES];
		[cssScanner setCharactersToBeSkipped:[NSCharacterSet newlineCharacterSet]];
		
		BOOL doFill = NO;
		int fillColor = 0;
		
		BOOL doStroke = NO;
		int strokeColor = 0;
		float strokeWidth = 1.0;
		
		NSString *currentAttribute;
		while ([cssScanner scanUpToString:@";" intoString:&currentAttribute]) {
			NSArray *attrAr = [currentAttribute componentsSeparatedByString:@":"];
			
			NSString *attrName = [attrAr objectAtIndex:0];
			NSString *attrValue = [attrAr objectAtIndex:1];
			
			// --------------------- FILL
			if([attrName isEqualToString:@"fill"]) {
				if(![attrValue isEqualToString:@"none"] && [attrValue rangeOfString:@"url"].location == NSNotFound) {
					doFill = YES;
					NSScanner *hexScanner = [NSScanner scannerWithString:[attrValue stringByReplacingOccurrencesOfString:@"#" withString:@"0x"]];
					[hexScanner setCharactersToBeSkipped:[NSCharacterSet symbolCharacterSet]]; 
					[hexScanner scanHexInt:&fillColor];
				}
			}
			
			// --------------------- STROKE
			if([attrName isEqualToString:@"stroke"]) {
				if(![attrValue isEqualToString:@"none"]) {
					doStroke = YES;
					NSScanner *hexScanner = [NSScanner scannerWithString:[attrValue stringByReplacingOccurrencesOfString:@"#" withString:@"0x"]];
					[hexScanner setCharactersToBeSkipped:[NSCharacterSet symbolCharacterSet]]; 
					[hexScanner scanHexInt:&strokeColor];
				}
			}
			
			// --------------------- STROKE-WIDTH
			if([attrName isEqualToString:@"stroke-width"]) {
				NSScanner *floatScanner = [NSScanner scannerWithString:[attrValue stringByReplacingOccurrencesOfString:@"px" withString:@""]];
				[floatScanner scanFloat:&strokeWidth];
			}
			
			[cssScanner scanString:@";" intoString:nil];
		}
		
		if(doFill) {
			CGFloat red   = ((fillColor & 0xFF0000) >> 16) / 255.0f;
			CGFloat green = ((fillColor & 0x00FF00) >>  8) / 255.0f;
			CGFloat blue  =  (fillColor & 0x0000FF) / 255.0f;
			[[NSColor colorWithDeviceRed:red green:green blue:blue alpha:1.0] set];
			[path fill];
		}
		
		if(doStroke) {
			CGFloat red   = ((strokeColor & 0xFF0000) >> 16) / 255.0f;
			CGFloat green = ((strokeColor & 0x00FF00) >>  8) / 255.0f;
			CGFloat blue  =  (strokeColor & 0x0000FF) / 255.0f;
			[[NSColor colorWithDeviceRed:red green:green blue:blue alpha:1.0] set];
			[path setLineWidth:strokeWidth];
			[path stroke];
		}
	}
	
	//[canvas unlockFocus];
}

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


@end
