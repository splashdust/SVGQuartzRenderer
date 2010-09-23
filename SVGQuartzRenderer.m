//
//  SVGWorldParser.m
//  StuntBike X
//
//  Created by Joacim Magnusson on 2010-09-20.
//  Copyright 2010 Joacim Magnusson. All rights reserved.
//

#import "SVGWorldParser.h"
#import "cocos2d.h"

@implementation SVGQuartzRenderer

- (CGImageRef)imageRefFromSVGFile:(NSString *)file
{
	
}

- (void)parser:(NSXMLParser *)parser
didStartElement:(NSString *)elementName 
  namespaceURI:(NSString *)namespaceURI
 qualifiedName:(NSString *)qualifiedName
	attributes:(NSDictionary *)attributeDict
{
	CGFloat scale = [[CCDirector sharedDirector] contentScaleFactor];
	
	if([elementName isEqualToString:@"svg"]) {
		worldHeight = [[attributeDict valueForKey:@"height"] intValue];
		worldSize = CGSizeMake([[attributeDict valueForKey:@"width"] intValue] * scale,
							   [[attributeDict valueForKey:@"height"] intValue] * scale);
	}
	
	if([elementName isEqualToString:@"path"]) {
		// Create Entity from SVG path
		NSScanner *scanner = [NSScanner scannerWithString:[attributeDict valueForKey:@"d"]];
		[scanner setCaseSensitive:YES];
		[scanner setCharactersToBeSkipped:[NSCharacterSet newlineCharacterSet]];
		
		WPolygonShape *newPoly = [[WPolygonShape alloc] init];
		newPoly.friction = 0.5;
		newPoly.restitution = 0.2;
		newPoly.density = 1.0;
		
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
						
						// Move to absolute coord
						if([currentCommand isEqualToString:@"M"]) {
							curPoint.x = [[param objectAtIndex:0] floatValue];
							curPoint.y = -[[param objectAtIndex:1] floatValue];
						}
						
						// Move to relative coord
						if([currentCommand isEqualToString:@"m"]) {
							curPoint.x += [[param objectAtIndex:0] floatValue];
							curPoint.y += -[[param objectAtIndex:1] floatValue];
						}
						
						// Line to absolute coord
						if([currentCommand isEqualToString:@"L"]) {
							curPoint.x = [[param objectAtIndex:0] floatValue];
							curPoint.y = -[[param objectAtIndex:1] floatValue];
						}
						
						// line to relative coord
						if([currentCommand isEqualToString:@"l"]) {
							curPoint.x += [[param objectAtIndex:0] floatValue];
							curPoint.y += -[[param objectAtIndex:1] floatValue];
						}
						
						WVertex *vertex = [WVertex vertexWithPoint:curPoint];
						[newPoly.vertices addObject:vertex];
						
						if(firstPoint.x == -1 && firstPoint.y == -1)
							firstPoint = curPoint;
						
						break;
					}
				}
			}
			
			[pool release];
			
			// Close path
			if([currentCommand isEqualToString:@"z"] || [currentCommand isEqualToString:@"Z"]) {
				WVertex *vertex = [WVertex vertexWithPoint:firstPoint];
				[newPoly.vertices addObject:vertex];
			}
			
			//NSLog(@"\nCommand: %@\nParams:%@", currentCommand, currentParams);
			
			
			currentParams = nil;
		}
		
		WEntity *newEntity = [[WEntity alloc] init];
		newEntity.id_no = 1;
		newEntity.name = @"test";
		newEntity.rotation = 0;
		newEntity.collisionMask = -1;
		newEntity.position = CGPointMake(-100,0);
		newEntity.isDynamic = NO;
		[[newEntity shapes] addObject:newPoly];
		
		[entities addObject:newEntity];
		
	}
}

- (void)parser:(NSXMLParser *)parser
 didEndElement:(NSString *)elementName
  namespaceURI:(NSString *)namespaceURI
 qualifiedName:(NSString *)qName
{
	
}


@end
