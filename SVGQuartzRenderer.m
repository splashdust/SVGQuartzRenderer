/*--------------------------------------------------
* Copyright (c) 2010 Joacim Magnusson
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

#import "SVGQuartzRenderer.h"
#import "NSData+Base64.h"
#import "SVGStyle.h"

@interface SVGQuartzRenderer (hidden)

- (void)drawPath:(CGMutablePathRef)path withStyle:(NSString *)style andIdentifier:(NSString*)identifier;
	- (void)applyTransformations:(NSString *)transformations;
	- (void) cleanupAfterFinishedParsing;

	void CGPathAddRoundRect(CGMutablePathRef path, CGRect rect, float radius);

	-(BOOL) doLocate:(CGPoint)location withBoundingBox:(CGSize)box;


@end

@implementation SVGQuartzRenderer

@synthesize viewFrame;
@synthesize documentSize;
@synthesize delegate;
@synthesize scaleX, scaleY, offsetX, offsetY,rotation;



typedef void (*CGPatternDrawPatternCallback) (void * info,
											  CGContextRef context);

NSXMLParser* xmlParser;
NSData *svgXml;
CGAffineTransform transform;
CGContextRef cgContext=NULL;
float initialScaleX = 1;
float initialScaleY = 1;
float width=0;
float height=0;
BOOL firstRender = YES;
NSMutableDictionary *defDict;



NSMutableDictionary *curPat;
NSMutableDictionary *curGradient;
NSMutableDictionary *curFilter;
NSMutableDictionary *curLayer;
NSDictionary *curText;
NSDictionary *curFlowRegion;

BOOL inDefSection = NO;

SVGStyle* currentStyle;

- (id)init {
    self = [super init];
    if (self) {
        xmlParser = [NSXMLParser alloc];
		offsetX = 0;
		offsetY = 0;
		rotation = 0;
		pathDict = [NSMutableDictionary new];
		
    }
    return self;
}

- (void)setDelegate:(id<SVGQuartzRenderDelegate>)rendererDelegate
{
	delegate = rendererDelegate;
}


- (void)drawSVGFile:(NSString *)file
{
	if (svgXml == nil)
	    svgXml = [NSData dataWithContentsOfFile:file];
	xmlParser = [xmlParser initWithData:svgXml];
	
	[xmlParser setDelegate:self];
	[xmlParser setShouldResolveExternalEntities:NO];
	[xmlParser parse];
}

- (void) resetScale
{
	scaleX = initialScaleX;
	scaleY = initialScaleY;
	
	
	[self doLocate:CGPointMake(0.5,0.5) withBoundingBox:CGSizeMake(1,1)];

	
}

-(CGPoint) relativeImagePointFrom:(CGPoint)viewPoint
{
    float x = (offsetX + viewPoint.x)/(scaleX*width);
	float y = (offsetY + viewPoint.y)/(scaleY*height);
	return CGPointMake(x,y);
}

-(BOOL) doLocate:(CGPoint)location withBoundingBox:(CGSize)box
{
	//reject locations outside of the image
	if (location.x <0 || location.y < 0 || location.x > 1 || location.y > 1)
		return NO;
	
	//reject bounding box that is not wholly contained in image
	if (box.width <0 || box.height < 0 || box.width > 1 || box.height > 1)
		return NO;
	
	scaleX = initialScaleX/box.width;
	scaleY = initialScaleY/box.height;
	
	//reverse calculation from relativeImagePointFrom above, with viewPoint set to middle of screen
	offsetX = -viewFrame.size.width/2 +  location.x* scaleX* width;
	offsetY = -viewFrame.size.height/2 + location.y * scaleY* height;
	
	
	return YES;
}


-(void) locate:(CGPoint)location withBoundingBox:(CGSize)box
{

	if ([self doLocate:location withBoundingBox:box])
	     [self drawSVGFile:nil];
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

		if (firstRender)
		{
			width = [[attrDict valueForKey:@"width"] floatValue];
			height = [[attrDict valueForKey:@"height"] floatValue];
			documentSize = viewFrame.size;	
			
			float sx = viewFrame.size.width/width;
			float sy = viewFrame.size.height/height;
			
			float scale =  fmax(sx,sy);
			initialScaleX =scale;
			initialScaleY = scale;
			scaleX = initialScaleX;
			scaleY = initialScaleY;
			
			[self doLocate:CGPointMake(0.5,0.5) withBoundingBox:CGSizeMake(1,1)];
		
			firstRender = NO;
		} 
			
		if(delegate) {
			
			cgContext = [delegate svgRenderer:self requestedCGContextWithSize:documentSize];
		}
		
		//default transformation
	    transform = CGAffineTransformScale(CGAffineTransformIdentity, scaleX, scaleY);	
		if (rotation != 0)
			transform = CGAffineTransformRotate(transform, rotation);	
		transform = CGAffineTransformTranslate(transform, -offsetX/scaleX, -offsetY/scaleY);
	    CGContextConcatCTM(cgContext,transform);
		
		currentStyle = [SVGStyle new];
	

	}
	
	// Definitions
	// -------------------------------------------------------------------------
	else if([elementName isEqualToString:@"defs"]) {
		defDict = [[NSMutableDictionary alloc] init];
		inDefSection = YES;
	}
	
	else if([elementName isEqualToString:@"pattern"]) {
		[curPat release];
		curPat = [[NSMutableDictionary alloc] init];
		
		NSEnumerator *enumerator = [attrDict keyEnumerator];
		id key;
		while ((key = [enumerator nextObject])) {
			NSDictionary *obj = [attrDict objectForKey:key];
			[curPat setObject:obj forKey:key];
		}
		NSMutableArray* imagesArray = [NSMutableArray new];
		[curPat setObject:imagesArray forKey:@"images"];
		[imagesArray release];
		[curPat setObject:@"pattern" forKey:@"type"];
	}
	else if([elementName isEqualToString:@"image"]) {
		NSMutableDictionary *imageDict = [[NSMutableDictionary alloc] init];
		NSEnumerator *enumerator = [attrDict keyEnumerator];
		id key;
		while ((key = [enumerator nextObject])) {
			NSDictionary *obj = [attrDict objectForKey:key];
			[imageDict setObject:obj forKey:key];
		}
		[[curPat objectForKey:@"images"] addObject:imageDict];
		[imageDict release];
	}
	
	else if([elementName isEqualToString:@"linearGradient"]) {
		[curGradient release];
		curGradient = [[NSMutableDictionary alloc] init];
		NSEnumerator *enumerator = [attrDict keyEnumerator];
		id key;
		while ((key = [enumerator nextObject])) {
			NSDictionary *obj = [attrDict objectForKey:key];
			[curGradient setObject:obj forKey:key];
		}
		[curGradient setObject:@"linearGradient" forKey:@"type"];
		NSMutableArray* stopsArray = [NSMutableArray new];
		[curGradient setObject:stopsArray forKey:@"stops"];
		[stopsArray release];
	}
	else if([elementName isEqualToString:@"stop"]) {
		NSMutableDictionary *stopDict = [[NSMutableDictionary alloc] init];
		NSEnumerator *enumerator = [attrDict keyEnumerator];
		id key;
		while ((key = [enumerator nextObject])) {
			NSDictionary *obj = [attrDict objectForKey:key];
			[stopDict setObject:obj forKey:key];
		}
		[[curGradient objectForKey:@"stops"] addObject:stopDict];
		[stopDict release];
	}
	
	else if([elementName isEqualToString:@"radialGradient"]) {
		[curGradient release];
		curGradient = [[NSMutableDictionary alloc] init];
		NSEnumerator *enumerator = [attrDict keyEnumerator];
		id key;
		while ((key = [enumerator nextObject])) {
			NSDictionary *obj = [attrDict objectForKey:key];
			[curGradient setObject:obj forKey:key];
		}
		[curGradient setObject:@"radialGradient" forKey:@"type"];
	}
	
	else if([elementName isEqualToString:@"filter"]) {
		[curFilter release];
		curFilter = [[NSMutableDictionary alloc] init];
		NSEnumerator *enumerator = [attrDict keyEnumerator];
		id key;
		while ((key = [enumerator nextObject])) {
			NSDictionary *obj = [attrDict objectForKey:key];
			[curFilter setObject:obj forKey:key];
		}
		NSMutableArray* gaussianBlursArray = [NSMutableArray new];
		[curFilter setObject:gaussianBlursArray forKey:@"feGaussianBlurs"];
		[gaussianBlursArray release];
	}
	else if([elementName isEqualToString:@"feGaussianBlur"]) {
		NSMutableDictionary *blurDict = [[NSMutableDictionary alloc] init];
		NSEnumerator *enumerator = [attrDict keyEnumerator];
		id key;
		while ((key = [enumerator nextObject])) {
			NSDictionary *obj = [attrDict objectForKey:key];
			[blurDict setObject:obj forKey:key];
		}
		[[curFilter objectForKey:@"feGaussianBlurs"] addObject:blurDict];
		[blurDict release];
	}
	else if([elementName isEqualToString:@"feColorMatrix"]) {
		
	}
	else if([elementName isEqualToString:@"feFlood"]) {
		
	}
	else if([elementName isEqualToString:@"feBlend"]) {
		
	}
	else if([elementName isEqualToString:@"feComposite"]) {
		
	}
	
	// Group node
	// -------------------------------------------------------------------------
	else if([elementName isEqualToString:@"g"]) {
		[curLayer release];
		curLayer = [[NSMutableDictionary alloc] init];
		NSEnumerator *enumerator = [attrDict keyEnumerator];
		id key;
		while ((key = [enumerator nextObject])) {
			NSDictionary *obj = [attrDict objectForKey:key];
			[curLayer setObject:obj forKey:key];
		}
		
		
		// Reset styles for each layer
		[currentStyle reset];
		
		if([attrDict valueForKey:@"style"])
			[currentStyle setStyleContext:[attrDict valueForKey:@"style"] withDefDict:defDict];

		if([attrDict valueForKey:@"transform"]) {
			[self applyTransformations:[attrDict valueForKey:@"transform"]];
		}
	}
	
	
	// Path node
	// -------------------------------------------------------------------------
	else if([elementName isEqualToString:@"path"]) {
		
		// For now, we'll ignore paths in definitions
		if(inDefSection)
			return;
		
		NSString* identifier = [attrDict valueForKey:@"id"]; 

		CGMutablePathRef path = CGPathCreateMutable();
		
		// Create a scanner for parsing path data
		NSString *d = [attrDict valueForKey:@"d"];
		
		// Space before the first command messes stuff up.
		if([d hasPrefix:@" "])
			d = [d stringByReplacingCharactersInRange:NSMakeRange(0, 1) withString:@""];
		
		NSScanner *scanner = [NSScanner scannerWithString:d];
		[scanner setCaseSensitive:YES];
		[scanner setCharactersToBeSkipped:[NSCharacterSet newlineCharacterSet]];
		
		CGPoint curPoint = CGPointMake(0,0);
		CGPoint curCtrlPoint1 = CGPointMake(-1,-1);
		CGPoint curCtrlPoint2 = CGPointMake(-1,-1);
		CGPoint curArcPoint = CGPointMake(-1,-1);
		CGPoint curArcRadius = CGPointMake(-1,-1);
		CGFloat curArcXRotation = 0.0;
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
						
						curArcXRotation = [[params objectAtIndex:prm_i++] floatValue];
						
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
						
						curArcXRotation = [[params objectAtIndex:prm_i++] floatValue];
						
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
						CGPathMoveToPoint(path, NULL, firstPoint.x, firstPoint.y);
					}
					
					// Close path
					if([currentCommand isEqualToString:@"z"] || [currentCommand isEqualToString:@"Z"]) {
						CGPathAddLineToPoint(path, NULL, firstPoint.x, firstPoint.y);
						CGPathCloseSubpath(path);
						curPoint = CGPointMake(-1, -1);
						firstPoint = CGPointMake(-1, -1);
						firstVertex = YES;
						prm_i++;
					}
					
					if(curCmdType) {
						if([curCmdType isEqualToString:@"line"]) {
							if(mCount>1) {
								CGPathAddLineToPoint(path, NULL, curPoint.x, curPoint.y);
							} else {
								CGPathMoveToPoint(path, NULL, curPoint.x, curPoint.y);
							}
						}
						
						if([curCmdType isEqualToString:@"curve"])
							CGPathAddCurveToPoint(path,NULL,curCtrlPoint1.x, curCtrlPoint1.y,
												  curCtrlPoint2.x, curCtrlPoint2.y,
												  curPoint.x,curPoint.y);
						
						if([curCmdType isEqualToString:@"arc"]) {
							CGPathAddArc (path, NULL,
										  curArcPoint.x,
										  curArcPoint.y,
										  curArcRadius.y,
										  curArcXRotation,
										  curArcXRotation,
										  TRUE);							
						}
					}
				} else {
					prm_i++;
				}
				
			}
			
			currentParams = nil;
		}
		
		
		if([attrDict valueForKey:@"transform"]) {
			[self applyTransformations:[attrDict valueForKey:@"transform"]];

		} 		
		// Respect the 'fill' attribute
		// TODO: This hex parsing stuff is in a bunch of places. It should be cetralized in a function instead.
		if([attrDict valueForKey:@"fill"]) {
			currentStyle.doFill = YES;
			currentStyle.fillType = @"solid";
			[currentStyle setFillColorFromAttribute:[attrDict valueForKey:@"fill"]];
		}
		
		//CGContextClosePath(cgContext);
		[self drawPath:path withStyle:[attrDict valueForKey:@"style"] andIdentifier:identifier];
		CGPathRelease(path);
	}
	
	
	// Rect node
	// -------------------------------------------------------------------------
	else if([elementName isEqualToString:@"rect"]) {
		
		// Ignore rects in flow regions for now
		if(curFlowRegion)
			return;
		
		NSString* identifier = [attrDict valueForKey:@"id"]; 

		
		float xPos = [[attrDict valueForKey:@"x"] floatValue];
		float yPos = [[attrDict valueForKey:@"y"] floatValue];
		float width = [[attrDict valueForKey:@"width"] floatValue];
		float height = [[attrDict valueForKey:@"height"] floatValue];
		float ry = [attrDict valueForKey:@"ry"]?[[attrDict valueForKey:@"ry"] floatValue]:-1.0;
		float rx = [attrDict valueForKey:@"rx"]?[[attrDict valueForKey:@"rx"] floatValue]:-1.0;
		
		if (ry==-1.0) ry = rx;
		if (rx==-1.0) rx = ry;
		
		CGMutablePathRef path = CGPathCreateMutable();
		CGPathAddRoundRect(path, CGRectMake(xPos,yPos ,width,height), rx);
		
		if([attrDict valueForKey:@"transform"]) {
			[self applyTransformations:[attrDict valueForKey:@"transform"]];
		} 
		
		// Respect the 'fill' attribute
		// TODO: This hex parsing stuff is in a bunch of places. It should be cetralized in a function instead.
		if([attrDict valueForKey:@"fill"]) {
			currentStyle.doFill = YES;
			currentStyle.fillType = @"solid";
			[currentStyle setFillColorFromAttribute:[attrDict valueForKey:@"fill"]];
		}
		
		[self drawPath:path withStyle:[attrDict valueForKey:@"style"] andIdentifier:identifier];
		CGPathRelease(path);
	}
	
	
	// Polygon node
	// -------------------------------------------------------------------------
	else if([elementName isEqualToString:@"polygon"]) {
		
		// Ignore polygons in flow regions for now
		if(curFlowRegion)
		{
			NSLog(@"In curFlowRegion");
			return;
		}
		
		NSString* identifier = [attrDict valueForKey:@"id"]; 

		
		NSCharacterSet *charset = [NSCharacterSet characterSetWithCharactersInString:@" \n"];
		
		// Extract the fill-rule attribute
		NSString* fill_rule = [attrDict valueForKey:@"fill-rule"];
		
		
		// Respect the 'fill' attribute
		// TODO: This hex parsing stuff is in a bunch of places. It should be cetralized in a function instead.
		if([attrDict valueForKey:@"fill"]) {
			currentStyle.doFill = YES;
			currentStyle.fillType = @"solid";
			[currentStyle setFillColorFromAttribute:[attrDict valueForKey:@"fill"]];
		}
		
		// Extract the points attribute and parse into a CGMutablePath
		CGMutablePathRef path = CGPathCreateMutable();
		BOOL firstPoint = YES;
		NSString *pointsString = [attrDict valueForKey:@"points"];
		NSArray *pointPairs = [pointsString componentsSeparatedByCharactersInSet:charset];
		for (NSString* pointPair in pointPairs)
		{
			if ([pointPair length] > 0)
			{
				NSArray *pointString = [pointPair componentsSeparatedByString:@","];
				float x = [[pointString objectAtIndex:0] floatValue];
				float y = [[pointString objectAtIndex:1] floatValue];
				//NSLog(@"Polygon point: (%f, %f)", x, y);
				
				if (firstPoint)
				{
					firstPoint = NO;
					CGPathMoveToPoint(path, NULL, x, y);
				}
				else
				{
					CGPathAddLineToPoint(path, NULL, x, y);
				}
			}
		}
		[self drawPath:path withStyle:[attrDict valueForKey:@"style"] andIdentifier:identifier];
		CGPathRelease(path);
		
	}
	
	
	
	// Image node
	// Parse the image node only if it contains an xlink:href attribute with base64 data
	// -------------------------------------------------------------------------
	else if([elementName isEqualToString:@"image"]
	   && [[attrDict valueForKey:@"xlink:href"] rangeOfString:@"base64"].location != NSNotFound) {
		
		if(inDefSection)
			return;
		
		float xPos = [[attrDict valueForKey:@"x"] floatValue];
		float yPos = [[attrDict valueForKey:@"y"] floatValue];
		float width = [[attrDict valueForKey:@"width"] floatValue];
		float height = [[attrDict valueForKey:@"height"] floatValue];
		
	
		if([attrDict valueForKey:@"transform"]) {
			[self applyTransformations:[attrDict valueForKey:@"transform"]];
		} 
		
		yPos-=height/2;
		CGImageRef theImage = imageFromBase64([attrDict valueForKey:@"xlink:href"]);
		CGAffineTransform flipVertical = CGAffineTransformMake(1, 0, 0, -1, 0, height);
		CGContextConcatCTM(cgContext, flipVertical);
		CGContextDrawImage(cgContext, CGRectMake(xPos, yPos, width, height), theImage);
		CGContextConcatCTM(cgContext, CGAffineTransformInvert(flipVertical));
		CGImageRelease(theImage);
	}
	
	// Text node
	// -------------------------------------------------------------------------
	else if([elementName isEqualToString:@"text"]) {
		
		if(inDefSection)
			return;
		
		if(curText)
			[curText release];
		
		// TODO: This chunk of code appears in almost every node. It could probably
		// be centralized
		if([attrDict valueForKey:@"transform"]) {
			[self applyTransformations:[attrDict valueForKey:@"transform"]];
		} 
		
		curText = [[[NSDictionary alloc] initWithObjectsAndKeys:
					[attrDict valueForKey:@"id"], @"id",
					[attrDict valueForKey:@"style"], @"style",
					[attrDict valueForKey:@"x"], @"x",
					[attrDict valueForKey:@"y"], @"y",
					[attrDict valueForKey:@"width"], @"width",
					[attrDict valueForKey:@"height"], @"height",
					nil] retain];
		
		[currentStyle setStyleContext:[attrDict valueForKey:@"style"] withDefDict:defDict];
	}
	
	// TSpan node
	// Assumed to always be a child of a Text node
	// ---------------------------------------------------------------------
	else if([elementName isEqualToString:@"tspan"]) {
		
		if(inDefSection)
			return;
		
		[currentStyle setStyleContext:[attrDict valueForKey:@"style"] withDefDict:defDict];
	}
	
	// FlowRegion node
	// -------------------------------------------------------------------------
	else if([elementName isEqualToString:@"flowRegion"]) {
		[curFlowRegion release];		
		curFlowRegion = [NSDictionary new];
	}
	
	[pool release];
}


- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)chars
{
	// TODO: Text rendering shouldn't occur in this method
	if(curText) {
		
		if(!currentStyle.font)
			currentStyle.font = @"Helvetica";
		
		CGContextSetRGBFillColor(cgContext, currentStyle.fillColor.r, currentStyle.fillColor.g, currentStyle.fillColor.b, currentStyle.fillColor.a);
		
		CGContextSelectFont(cgContext, [currentStyle.font UTF8String], currentStyle.fontSize, kCGEncodingMacRoman);
		CGContextSetFontSize(cgContext, currentStyle.fontSize);
		CGContextSetTextMatrix(cgContext, CGAffineTransformMakeScale(1.0, -1.0));
		
		[currentStyle setUpStroke:cgContext];
		
		
		CGTextDrawingMode drawingMode = kCGTextInvisible;			
		if(currentStyle.doStroke && currentStyle.doFill)
			drawingMode = kCGTextFillStroke;
		else if(currentStyle.doFill)
			drawingMode = kCGTextFill;				
		else if(currentStyle.doStroke)
			drawingMode = kCGTextStroke;
		
		CGContextSetTextDrawingMode(cgContext, drawingMode);
		CGContextShowTextAtPoint(cgContext,
								 [[curText valueForKey:@"x"] floatValue],
								 [[curText valueForKey:@"y"] floatValue],
								 [chars UTF8String],
								 [chars length]);
	}
}



// Element ended
// -----------------------------------------------------------------------------
- (void)parser:(NSXMLParser *)parser
 didEndElement:(NSString *)elementName
  namespaceURI:(NSString *)namespaceURI
 qualifiedName:(NSString *)qName
{
	if([elementName isEqualToString:@"svg"]) {
		delegate?[delegate svgRenderer:self finishedRenderingInCGContext:cgContext]:nil;
		[self cleanupAfterFinishedParsing];
	}
	
	else if([elementName isEqualToString:@"g"]) {
	}
	
	else if([elementName isEqualToString:@"defs"]) {
		inDefSection = NO;
	}

	else if([elementName isEqualToString:@"path"]) {
	}
	
	else if([elementName isEqualToString:@"text"]) {
		if(curText) {
			[curText release];
			curText = nil;
		}
	}
	
	else if([elementName isEqualToString:@"flowRegion"]) {
		if(curFlowRegion) {
			[curFlowRegion release];
			curFlowRegion = nil;
		}
	}
	
	else if([elementName isEqualToString:@"pattern"]) {
		if([curPat objectForKey:@"id"])
		[defDict setObject:curPat forKey:[curPat objectForKey:@"id"]];
	}
	
	else if([elementName isEqualToString:@"linearGradient"]) {
		if([curGradient objectForKey:@"id"])
		[defDict setObject:curGradient forKey:[curGradient objectForKey:@"id"]];
	}
	
	else if([elementName isEqualToString:@"radialGradient"]) {
		if([curGradient objectForKey:@"id"])
		[defDict setObject:curGradient forKey:[curGradient objectForKey:@"id"]];
	}
}


// Draw a path based on style information
// -----------------------------------------------------------------------------
- (void)drawPath:(CGMutablePathRef)path withStyle:(NSString *)style andIdentifier:(NSString*)identifier
{		
	CGContextSaveGState(cgContext);
	if(style)
		[currentStyle setStyleContext:style withDefDict:defDict];
	
	SVGStyle* idStyle;
	if (identifier)
	{
		
		NSObject* obj = [pathDict objectForKey:identifier];
		if (!obj)
		{
			SVGStyle* newStyle = [currentStyle copyWithZone:nil];
			[pathDict setObject:newStyle forKey:identifier];
			[newStyle release];
			idStyle = currentStyle;
			
		}else {
			idStyle = (SVGStyle*)obj;
		}


	}
	
	
	if ([identifier isEqualToString:@"starry_night"] || [identifier isEqualToString:@"self_portrait"])
	{
	    idStyle.isActive = YES; 
	}
	
	FILL_COLOR oldColor;
	if (idStyle.isActive)
		[currentStyle setFillColorFromInt:0x00FF0000];
	
    [currentStyle drawPath:path withContext:cgContext];	
	if (idStyle.isActive)
	  currentStyle.fillColor = oldColor;
	CGContextRestoreGState(cgContext);
	
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
	NSArray *values;
	float sx = scaleX, sy = scaleY;
	
	// Matrix
	BOOL hasMatrix = [scanner scanString:@"matrix(" intoString:nil];
	if (hasMatrix)
	{
		[scanner scanUpToString:@")" intoString:&value];
		
		values = [value componentsSeparatedByString:@","];
		
		if([values count] == 6) {
			float a = [[values objectAtIndex:0] floatValue];
			float b = [[values objectAtIndex:1] floatValue];
			float c = [[values objectAtIndex:2] floatValue];
			float d = [[values objectAtIndex:3] floatValue];
			
	
			// local translation, with correction for global scale		
			float tx = [[values objectAtIndex:4] floatValue]*sx;
			float ty = [[values objectAtIndex:5] floatValue]*sy;

			//move all scaling into separate transformation
			float scl = sqrtf(a*d - b*c);  //!!!!!!!  assume local x scale = local y scale
			a /= scl;
			d /= scl;
			if (sx != 1.0 || sy != 1.0)
				transform = CGAffineTransformScale(transform, sx*scl, sy*scl);
			
			//global rotation
			if (rotation != 0)
				transform = CGAffineTransformRotate(transform, rotation);
			
			
			CGAffineTransform matrixTransform = CGAffineTransformMake (a,b,c,d, tx - offsetX, ty - offsetY);

			transform = CGAffineTransformConcat(transform, matrixTransform);
			
			// Apply to graphics context
			CGContextConcatCTM(cgContext,transform);
						
			return;
			
		}
		
	}
	
	
	// Scale
	BOOL hasScale = [scanner scanString:@"scale(" intoString:nil];
	if (hasScale)
	{
			
		[scanner scanUpToString:@")" intoString:&value];
		
		values = [value componentsSeparatedByString:@","];

		if([values count] == 2)
		{
			sx *= 	[[values objectAtIndex:0] floatValue];
			sy *=  [[values objectAtIndex:1] floatValue];		
		}

	}
	if (sx != 1.0 || sy != 1.0)
		transform = CGAffineTransformScale(transform, sx, sy);
	
	
	// Rotate
	float currentRotation = rotation;
	BOOL hasRotate = [scanner scanString:@"rotate(" intoString:nil];
	if (hasRotate)
	{
		[scanner scanUpToString:@")" intoString:&value];
		
		if(value)
			currentRotation += [value floatValue];
		
	}
	
	if (currentRotation != 0)
		transform = CGAffineTransformRotate(transform, currentRotation);
	

	
	// Translate
	float transX = -offsetX/sx;
	float transY = -offsetY/sy;
	
	BOOL hasTrans = [scanner scanString:@"translate(" intoString:nil];
	if (hasTrans)
	{
		
		[scanner scanUpToString:@")" intoString:&value];
		
		values = [value componentsSeparatedByString:@","];
		
		
		if([values count] == 2)
		{
			transX += 	[[values objectAtIndex:0] floatValue] ;
			transY += [[values objectAtIndex:1] floatValue];			
			
		}
		
	}
	
	if (transX != 0 || transY != 0)
		transform = CGAffineTransformTranslate(transform, transX, transY);			

	// Apply to graphics context
	CGContextConcatCTM(cgContext,transform);
}


- (CGContextRef)createBitmapContext
{
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	CGContextRef ctx = CGBitmapContextCreate(NULL, (int)documentSize.width, (int)documentSize.height, 8, (int)documentSize.width*4, colorSpace, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(colorSpace);
	return ctx;
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
	[self cleanupAfterFinishedParsing];
	[xmlParser release];
	[pathDict release];
	[super dealloc];
}

-(void) cleanupAfterFinishedParsing
{
	[defDict release];
	defDict = nil;
	[curPat release];
	curPat = nil;
	[curGradient release];
	curGradient = nil;
	[curFilter release];
	curFilter = nil;
	[curText release];
	curText = nil;
	CGContextRelease(cgContext);
	cgContext = NULL;
	[curFlowRegion release];
	curFlowRegion = nil;
	[currentStyle release];
	currentStyle = nil;

	
}

@end
