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

@interface SVGQuartzRenderer (hidden)

	- (void)setStyleContext:(NSString *)style;
	- (void)drawPath:(CGMutablePathRef)path withStyle:(NSString *)style;
	- (void)applyTransformations:(NSString *)transformations;
	- (NSDictionary *)getCompleteDefinitionFromID:(NSString *)identifier;
	- (void) cleanupAfterFinishedParsing;

	void CGPathAddRoundRect(CGMutablePathRef path, CGRect rect, float radius);
	void drawImagePattern(void *fillPatDescriptor, CGContextRef context);
	CGImageRef imageFromBase64(NSString *b64Data);


@end

@implementation SVGQuartzRenderer

@synthesize viewFrame;
@synthesize documentSize;
@synthesize delegate;
@synthesize scaleX, scaleY, offsetX, offsetY,rotation;

struct FillPatternDescriptor {
	CGImageRef imgRef;
	CGRect rect;
}; typedef struct FillPatternDescriptor FillPatternDescriptor;

typedef void (*CGPatternDrawPatternCallback) (void * info,
											  CGContextRef context);

NSXMLParser* xmlParser;
NSData *svgXml;
CGAffineTransform transform;
CGContextRef cgContext=NULL;
float initialScaleX = 1;
float initialScaleY = 1;
BOOL firstRender = YES;
NSMutableDictionary *defDict;
FillPatternDescriptor desc;

NSMutableDictionary *curPat;
NSMutableDictionary *curGradient;
NSMutableDictionary *curFilter;
NSMutableDictionary *curLayer;
NSDictionary *curText;
NSDictionary *curFlowRegion;

BOOL inDefSection = NO;



// Variables for storing style data
// -------------------------------------------------------------------------
// TODO: This is very messy. Create a class that contains all of these values.
// Then the styling for an element can be represented by a style object.
// Also, the style object could be responsible for parsing CSS and for configuring
// the CGContext according to it's style.
BOOL doFill;
CGFloat fillColor[4];
float fillOpacity;
BOOL doStroke = NO;
unsigned int strokeColor = 0;
float strokeWidth = 1.0;
float strokeOpacity;
CGLineJoin lineJoinStyle;
CGLineCap lineCapStyle;
float miterLimit;
CGPatternRef fillPattern=NULL;
NSString *fillType;
CGGradientRef fillGradient=NULL;
CGPoint fillGradientPoints[2];
int fillGradientAngle;
CGPoint fillGradientCenterPoint;
NSString *font;
float fontSize;
// -------------------------------------------------------------------------

- (id)init {
    self = [super init];
    if (self) {
        xmlParser = [NSXMLParser alloc];
		transform = CGAffineTransformIdentity;

		defDict = [[NSMutableDictionary alloc] init];
		
		scaleX = 1.0;
		scaleY = 1.0;
		offsetX = 0;
		offsetY = 0;
		rotation = 0;
		documentSize = CGSizeMake(0,0);
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
	strokeWidth = 1.0;
	strokeOpacity = 1.0;
	lineJoinStyle = kCGLineJoinMiter;
	lineCapStyle = kCGLineCapButt;
	miterLimit = 4;
	fillType = @"solid";
	fillGradientAngle = 0;
	fillGradientCenterPoint = CGPointMake(0, 0);
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
	
}

-(CGPoint) relativeImagePointFrom:(CGPoint)viewPoint
{
    float x = ((offsetX + viewPoint.x)/scaleX)*initialScaleX/viewFrame.size.width;
	float y = ((offsetY + viewPoint.y)/scaleY)*initialScaleY/viewFrame.size.height;
	return CGPointMake(x,y);
}

-(void) locate:(CGPoint)location withBoundingBox:(CGSize)box
{
	// image coordinate system
	float offx = (location.x - box.width/2) * documentSize.width/initialScaleX;
	float offy = (location.y - box.height/2) * documentSize.height/initialScaleY;
	
	scaleX = initialScaleX / box.width;
	scaleY = initialScaleY / box.height;
	offsetX = initialScaleX * offx;
	offsetY = initialScaleY * offy;
	
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
			float w = [[attrDict valueForKey:@"width"] floatValue];
			float h = [[attrDict valueForKey:@"height"] floatValue];
			float scaleW = (float)viewFrame.size.width/w;
			float scaleH = (float)viewFrame.size.height/h;
			float s = fmaxf(scaleW, scaleH);
			documentSize = CGSizeMake(s*w,s*h);			
			
			float scale = (float)viewFrame.size.width/documentSize.width;
			initialScaleX = s*scale;
			initialScaleY = s*scale;
			scaleX = initialScaleX;
			scaleY = initialScaleY;
			firstRender = NO;
		} 
		
		doStroke = NO;
		
		if(delegate) {
			
			cgContext = [delegate svgRenderer:self requestedCGContextWithSize:documentSize];
		}
		
		//default transformation
	    transform = CGAffineTransformScale(CGAffineTransformIdentity, scaleX, scaleY);	
		if (rotation != 0)
			transform = CGAffineTransformRotate(transform, rotation);	
		transform = CGAffineTransformTranslate(transform, -offsetX/scaleX, -offsetY/scaleY);
	    CGContextConcatCTM(cgContext,transform);
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
		[self resetStyleContext];
		
		if([attrDict valueForKey:@"style"])
			[self setStyleContext:[attrDict valueForKey:@"style"]];

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
			doFill = YES;
			fillType = @"solid";
			NSScanner *hexScanner = [NSScanner scannerWithString:
									 [[attrDict valueForKey:@"fill"] stringByReplacingOccurrencesOfString:@"#" withString:@"0x"]];
			[hexScanner setCharactersToBeSkipped:[NSCharacterSet symbolCharacterSet]]; 
			unsigned int color;
			[hexScanner scanHexInt:&color];
			fillColor[0] = ((color & 0xFF0000) >> 16) / 255.0f;
			fillColor[1] = ((color & 0x00FF00) >>  8) / 255.0f;
			fillColor[2] =  (color & 0x0000FF) / 255.0f;
			fillColor[3] = 1;
		}
		
		//CGContextClosePath(cgContext);
		[self drawPath:path withStyle:[attrDict valueForKey:@"style"]];
		CGPathRelease(path);
	}
	
	
	// Rect node
	// -------------------------------------------------------------------------
	else if([elementName isEqualToString:@"rect"]) {
		
		// Ignore rects in flow regions for now
		if(curFlowRegion)
			return;
		
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
			doFill = YES;
			fillType = @"solid";
			NSScanner *hexScanner = [NSScanner scannerWithString:
									 [[attrDict valueForKey:@"fill"] stringByReplacingOccurrencesOfString:@"#" withString:@"0x"]];
			[hexScanner setCharactersToBeSkipped:[NSCharacterSet symbolCharacterSet]]; 
			unsigned int color;
			[hexScanner scanHexInt:&color];
			fillColor[0] = ((color & 0xFF0000) >> 16) / 255.0f;
			fillColor[1] = ((color & 0x00FF00) >>  8) / 255.0f;
			fillColor[2] =  (color & 0x0000FF) / 255.0f;
			fillColor[3] = 1;
		}
		
		[self drawPath:path withStyle:[attrDict valueForKey:@"style"]];
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
		
		NSCharacterSet *charset = [NSCharacterSet characterSetWithCharactersInString:@" \n"];
		
		// Extract the fill-rule attribute
		NSString* fill_rule = [attrDict valueForKey:@"fill-rule"];
		
		
		// Respect the 'fill' attribute
		// TODO: This hex parsing stuff is in a bunch of places. It should be cetralized in a function instead.
		if([attrDict valueForKey:@"fill"]) {
			doFill = YES;
			fillType = @"solid";
			NSScanner *hexScanner = [NSScanner scannerWithString:
									 [[attrDict valueForKey:@"fill"] stringByReplacingOccurrencesOfString:@"#" withString:@"0x"]];
			[hexScanner setCharactersToBeSkipped:[NSCharacterSet symbolCharacterSet]];
			unsigned int color;
			[hexScanner scanHexInt:&color];
			fillColor[0] = ((color & 0xFF0000) >> 16) / 255.0f;
			fillColor[1] = ((color & 0x00FF00) >>  8) / 255.0f;
			fillColor[2] =  (color & 0x0000FF) / 255.0f;
			fillColor[3] = 1;
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
		[self drawPath:path withStyle:[attrDict valueForKey:@"style"]];
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
		
		[self setStyleContext:[attrDict valueForKey:@"style"]];
	}
	
	// TSpan node
	// Assumed to always be a child of a Text node
	// ---------------------------------------------------------------------
	else if([elementName isEqualToString:@"tspan"]) {
		
		if(inDefSection)
			return;
		
		[self setStyleContext:[attrDict valueForKey:@"style"]];
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
		
		if(!font)
			font = @"Helvetica";
		
		CGContextSetRGBFillColor(cgContext, fillColor[0], fillColor[1], fillColor[2], fillColor[3]);
		
		CGContextSelectFont(cgContext, [font UTF8String], fontSize, kCGEncodingMacRoman);
		CGContextSetFontSize(cgContext, fontSize);
		CGContextSetTextMatrix(cgContext, CGAffineTransformMakeScale(1.0, -1.0));
		
		// TODO: Messy! Centralize.
		CGFloat red   = ((strokeColor & 0xFF0000) >> 16) / 255.0f;
		CGFloat green = ((strokeColor & 0x00FF00) >>  8) / 255.0f;
		CGFloat blue  =  (strokeColor & 0x0000FF) / 255.0f;
		CGContextSetRGBStrokeColor(cgContext, red, green, blue, strokeOpacity);
		CGContextSetLineWidth(cgContext, strokeWidth);
		CGContextSetLineCap(cgContext, lineCapStyle);
		CGContextSetLineJoin(cgContext, lineJoinStyle);
		CGContextSetMiterLimit(cgContext, miterLimit);
		
		
		CGTextDrawingMode drawingMode = kCGTextInvisible;			
		if(doStroke && doFill)
			drawingMode = kCGTextFillStroke;
		else if(doFill)
			drawingMode = kCGTextFill;				
		else if(doStroke)
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
- (void)drawPath:(CGMutablePathRef)path withStyle:(NSString *)style
{		
	CGContextSaveGState(cgContext);
	if(style)
		[self setStyleContext:style];
	

	
	if(doFill) {
		if ([fillType isEqualToString:@"solid"]) {
			
			//NSLog(@"Setting fill color R:%f, G:%f, B:%f, A:%f", fillColor[0], fillColor[1], fillColor[2], fillColor[3]);
			CGContextSetRGBFillColor(cgContext, fillColor[0], fillColor[1], fillColor[2], fillColor[3]);
			
		} else if([fillType isEqualToString:@"pattern"]) {
			
			CGColorSpaceRef myColorSpace = CGColorSpaceCreatePattern(NULL);
			CGContextSetFillColorSpace(cgContext, myColorSpace);
			CGColorSpaceRelease(myColorSpace);
			
			CGFloat alpha = fillColor[3];
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
	
	if(doFill || doStroke) {
		CGContextAddPath(cgContext, path);
		//NSLog(@"Adding path to contextl");
	}
	
	if(doFill && doStroke) {
		CGContextDrawPath(cgContext, kCGPathFillStroke);
	} else if(doFill) {
		CGContextFillPath(cgContext);
		//NSLog(@"Filling path in contextl");
	} else if(doStroke) {
		CGContextStrokePath(cgContext);
	}
	
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
						CGImageRef patternImage = imageFromBase64(imgString);
						
						CGImageRetain(patternImage);
						
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
							fillGradientPoints[0] = CGPointMake([[def objectForKey:@"x1"] floatValue] ,[[def objectForKey:@"y1"] floatValue] );
							fillGradientPoints[1] = CGPointMake([[def objectForKey:@"x2"] floatValue] ,[[def objectForKey:@"y2"] floatValue] );
							//fillGradientAngle = (((atan2(([[def objectForKey:@"x1"] floatValue] - [[def objectForKey:@"x2"] floatValue]),
							//											([[def objectForKey:@"y1"] floatValue] - [[def objectForKey:@"y2"] floatValue])))*180)/M_PI)+90;
						} if([def objectForKey:@"cx"]) {
							fillGradientCenterPoint.x = [[def objectForKey:@"cx"] floatValue] ;
							fillGradientCenterPoint.y = [[def objectForKey:@"cy"] floatValue] ;
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
			float temp;
			[floatScanner scanFloat:&temp];
			fillColor[3] = temp;
		}
		
		// --------------------- STROKE
		if([attrName isEqualToString:@"stroke"]) {
			if(![attrValue isEqualToString:@"none"]) {
				doStroke = YES;
				NSScanner *hexScanner = [NSScanner scannerWithString:
										 [attrValue stringByReplacingOccurrencesOfString:@"#" withString:@"0x"]];
				[hexScanner setCharactersToBeSkipped:[NSCharacterSet symbolCharacterSet]]; 
				[hexScanner scanHexInt:&strokeColor];
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
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	CGContextRef ctx = CGBitmapContextCreate(NULL, (int)documentSize.width, (int)documentSize.height, 8, (int)documentSize.width*4, colorSpace, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(colorSpace);
	return ctx;
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
	[font release];
	font = nil;
	CGContextRelease(cgContext);
	cgContext = NULL;
	CGGradientRelease(fillGradient);
	fillGradient = NULL;
	[curFlowRegion release];
	curFlowRegion = nil;
	CGPatternRelease(fillPattern);
	fillPattern = NULL;
	
}

@end
