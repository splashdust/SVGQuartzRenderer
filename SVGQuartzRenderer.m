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
#import "Sprite.h"
#import "math.h"
#import "float.h"
#import "QuadTreeNode.h"
#import "PathFrag.h"
#import "CGPathReader.h"


// Function prototypes for SAX callbacks. This sample implements a minimal subset of SAX callbacks.
// Depending on your application's needs, you might want to implement more callbacks.
static void startElementSAX(void *ctx, const xmlChar *localname, const xmlChar *prefix, const xmlChar *URI, int nb_namespaces, const xmlChar **namespaces, int nb_attributes, int nb_defaulted, const xmlChar **attributes);
static void	endElementSAX(void *ctx, const xmlChar *localname, const xmlChar *prefix, const xmlChar *URI);
static void	charactersFoundSAX(void * ctx, const xmlChar * ch, int len);
static void errorEncounteredSAX(void * ctx, const char * msg, ...);

// Forward reference. The structure is defined in full at the end of the file.
static xmlSAXHandler simpleSAXHandlerStruct;

@interface SVGQuartzRenderer (hidden)

    - (void) prepareToDraw;
     -(void) drawPath;
    - (void)drawPath:(CGPathRef)path withStyle:(SVGStyle*)style;
	- (SVG_TRANS)applyTransformations:(NSString *)transformations;
    - (void)applyTransformation:(SVG_TRANS)trans;
	- (void) cleanupAfterFinishedParsing;

	void CGPathAddRoundRect(CGMutablePathRef currPath, CGRect rect, float radius);

	-(BOOL) doCenter:(CGPoint)location withBoundingBox:(CGSize)box;

    -(Sprite*) currentSprite;

    -(void) copyDict:(NSDictionary*) src toDest:(NSMutableDictionary*) dest;
    -(void) copyAttributes:(const xmlChar **) attributes size:(int)nb_attributes toDest:(NSMutableDictionary*) dest;
 


@end

@implementation SVGQuartzRenderer

@synthesize viewFrame;
@synthesize documentSize;
@synthesize delegate;
@synthesize globalScaleX, globalScaleY, offsetX, offsetY;
@synthesize curLayerName;

typedef void (*CGPatternDrawPatternCallback) (void * info, CGContextRef context);

- (id)init {
    self = [super init];
    if (self) {

		offsetX = 0;
		offsetY = 0;
		sprites = [NSMutableDictionary new];
        fragments = [NSMutableArray new];
		firstRender = YES;
		inDefSection = NO;
		rootNode = [[QuadTreeNode alloc] initWithRect:CGRectMake(0,0,1,1)]; 
		
    }
    return self;
}

-(CGPoint) getTranslation
{
    return CGPointMake(-offsetX, -offsetY);
}
-(CGPoint) getScale
{
    return CGPointMake(globalScaleX, globalScaleY);
}

- (void)setDelegate:(id<SVGQuartzRenderDelegate>)rendererDelegate
{
	delegate = rendererDelegate;
}


- (void)drawSVGFile:(NSString *)file
{
	if (svgXml == nil)
    {
        
	    svgXml = [NSData dataWithContentsOfFile:file];

        xmlParser = [[NSXMLParser alloc] initWithData:svgXml];
        [xmlParser setDelegate:self];
        [xmlParser setShouldResolveExternalEntities:NO];
    }
    NSDate* start;
    NSTimeInterval timeInterval;
  /*  
      NSDate *start = [NSDate date];  
     // This creates a context for "push" parsing in which chunks of data that are not "well balanced" can be passed
     // to the context for streaming parsing. The handler structure defined above will be used for all the parsing. 
     // The second argument, self, will be passed as user data to each of the SAX handlers. The last three arguments
     // are left blank to avoid creating a tree in memory.
     context = xmlCreatePushParserCtxt(&simpleSAXHandlerStruct, self, NULL, 0, NULL);
     xmlParseChunk(context, (const char *)[svgXml bytes], [svgXml length], 0);
     
     
     // Signal the context that parsing is complete by passing "1" as the last parameter.
     xmlParseChunk(context, NULL, 0, 1);
     
     // Release resources used only in this thread.
     xmlFreeParserCtxt(context);
    
    timeInterval = [start timeIntervalSinceNow];
    NSLog(@"lib2xml Time to parse: %f",-timeInterval);    
 */   
    start = [NSDate date];
	[xmlParser parse];
    
    timeInterval = [start timeIntervalSinceNow];
    NSLog(@"NSXMLParser Time to parse: %f",-timeInterval);    
    

}

-(void) redraw
{
  if (YES)
  {
     [self drawSVGFile:nil];
   
  }
else
{
    if(delegate) {
        
        CGContextRelease(cgContext);
        cgContext = [delegate svgRenderer:self requestedCGContextWithSize:documentSize];
    }

    for (int i = 0; i < [fragments count]; ++i)
    {
        PathFrag* frag = (PathFrag*)[fragments objectAtIndex:i];
        [frag draw:cgContext];
    }
    if (delegate)
        [delegate svgRenderer:self finishedRenderingInCGContext:cgContext];
    
    [self cleanupAfterFinishedParsing];
}   
    
}

- (void) resetScale
{
	globalScaleX = initialScaleX;
	globalScaleY = initialScaleY;
	
	
	[self doCenter:CGPointMake(0.5,0.5) withBoundingBox:CGSizeMake(1,1)];
	
}


-(CGPoint) scaledImagePointFromViewPoint:(CGPoint)viewPoint
{
    float x = (offsetX + viewPoint.x)/(globalScaleX*width);
	float y = (offsetY + viewPoint.y)/(globalScaleY*height);
	return CGPointMake(x,y);
}

-(BOOL) doCenter:(CGPoint)location withBoundingBox:(CGSize)box
{
	//reject locations outside of the image
	if (location.x <0 || location.y < 0 || location.x > 1 || location.y > 1)
		return NO;
	
	//reject bounding box that is not wholly contained in image
	if (box.width <0 || box.height < 0 || box.width > 1 || box.height > 1)
		return NO;
	
	globalScaleX = initialScaleX/box.width;
	globalScaleY = initialScaleY/box.height;
	
	//reverse calculation from relativeImagePointFrom above, with viewPoint set to middle of screen
	offsetX = -viewFrame.size.width/2 +  location.x* globalScaleX* width;
	offsetY = -viewFrame.size.height/2 + location.y * globalScaleY* height;
	
	
	return YES;
}


-(void) center:(CGPoint)location withBoundingBox:(CGSize)box
{

	if ([self doCenter:location withBoundingBox:box])
	     [self drawSVGFile:nil];
}

-(NSString*) find:(CGPoint)viewPoint
{
	// un-highlight all sprites
	NSEnumerator *enumerator = [sprites keyEnumerator];
	id key;
	while ((key = [enumerator nextObject])) {
		Sprite* sprite = [sprites objectForKey:key];
		sprite.isHighlighted = NO;
	}
	
	NSArray* group = [rootNode groupContainingPoint:[self scaledImagePointFromViewPoint:viewPoint]];
	if (group != nil && [group count] > 0)
	{
	
		Sprite* sprite =  (Sprite*)[group objectAtIndex:0];
		sprite.isHighlighted = YES;
		return sprite.name;
		
	}
	return nil;
	
}

- (void) prepareToDraw
{
    if(delegate) {
        
        CGContextRelease(cgContext);
        cgContext = [delegate svgRenderer:self requestedCGContextWithSize:documentSize];
    }
    
    
    //default transformation
    transform = CGAffineTransformScale(CGAffineTransformIdentity, globalScaleX, globalScaleY);	
    transform = CGAffineTransformTranslate(transform, -offsetX/globalScaleX, -offsetY/globalScaleY);
    CGContextConcatCTM(cgContext,transform);
    
}

-(void) copyDict:(NSDictionary*) src toDest:(NSMutableDictionary*) dest
{
  	NSEnumerator *enumerator = [src keyEnumerator];
    id key;
    while ((key = [enumerator nextObject])) {
        NSDictionary *obj = [src objectForKey:key];
        [dest setObject:obj forKey:key];
    }  
    
}

-(void) copyAttributes:(const xmlChar **) attributes size:(int)nb_attributes toDest:(NSMutableDictionary*) dest
{
    unsigned int index = 0;
    for ( int indexAttribute = 0; 
         indexAttribute < nb_attributes; 
         ++indexAttribute, index += 5 )
    {
        const xmlChar *localname = attributes[index];
      // const xmlChar *prefix = attributes[index+1];
      //  const xmlChar *nsURI = attributes[index+2];
        const xmlChar *valueBegin = attributes[index+3];
        const xmlChar *valueEnd = attributes[index+4];
        int vlen = valueEnd - valueBegin;
        xmlChar val[vlen + 1];
        strncpy((char*)val, (const char*)valueBegin, vlen);
        val[vlen] = '\0';
        NSString* key = [NSString stringWithUTF8String:(char*)localname];
        NSString* nsval = [NSString stringWithUTF8String:(char*)val];
        [dest setObject:nsval forKey:key];
        /*
        printf( "  attribute: localname='%s', prefix='%s', uri=(%p)'%s', value='%s'\n",
               localname,
               prefix,
               nsURI,
               nsURI,
               val);
         */
    }

    
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
	
	NSString* temp = [attrDict valueForKey:@"id"];
	if (temp)
	   currId = [NSString stringWithString:temp]; 
	
	// Top level SVG node
    const char* element = [elementName UTF8String];
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
			globalScaleX = initialScaleX;
			globalScaleY = initialScaleY;
			
			[self doCenter:CGPointMake(0.5,0.5) withBoundingBox:CGSizeMake(1,1)];
		
			firstRender = NO;
		} 
			
        [self prepareToDraw];
		
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
        [self copyDict:attrDict toDest:curPat];
	
		NSMutableArray* imagesArray = [NSMutableArray new];
		[curPat setObject:imagesArray forKey:@"images"];
		[imagesArray release];
		[curPat setObject:@"pattern" forKey:@"type"];
	}
	else if([elementName isEqualToString:@"image"]) {
		NSMutableDictionary *imageDict = [[NSMutableDictionary alloc] init];
        [self copyDict:attrDict toDest:imageDict];
		[[curPat objectForKey:@"images"] addObject:imageDict];
		[imageDict release];
	}
	
	else if([elementName isEqualToString:@"linearGradient"]) {
		[curGradient release];
		curGradient = [[NSMutableDictionary alloc] init];
        [self copyDict:attrDict toDest:curGradient];
		
		[curGradient setObject:@"linearGradient" forKey:@"type"];
		NSMutableArray* stopsArray = [NSMutableArray new];
		[curGradient setObject:stopsArray forKey:@"stops"];
		[stopsArray release];
	}
	else if([elementName isEqualToString:@"stop"]) {
		NSMutableDictionary *stopDict = [[NSMutableDictionary alloc] init];
        [self copyDict:attrDict toDest:stopDict];        
		[[curGradient objectForKey:@"stops"] addObject:stopDict];
		[stopDict release];
	}
	
	else if([elementName isEqualToString:@"radialGradient"]) {
		[curGradient release];
		curGradient = [[NSMutableDictionary alloc] init];
        [self copyDict:attrDict toDest:curGradient];
  
		[curGradient setObject:@"radialGradient" forKey:@"type"];
	}
	
	else if([elementName isEqualToString:@"filter"]) {
		[curFilter release];
		curFilter = [[NSMutableDictionary alloc] init];
        [self copyDict:attrDict toDest:curFilter];

		NSMutableArray* gaussianBlursArray = [NSMutableArray new];
		[curFilter setObject:gaussianBlursArray forKey:@"feGaussianBlurs"];
		[gaussianBlursArray release];
	}
	else if([elementName isEqualToString:@"feGaussianBlur"]) {
		NSMutableDictionary *blurDict = [[NSMutableDictionary alloc] init];
        [self copyDict:attrDict toDest:blurDict]; 

		[[curFilter objectForKey:@"feGaussianBlurs"] addObject:blurDict];
		[blurDict release];
	}
   
    //ToDo    
//	else if([elementName isEqualToString:@"feColorMatrix"]) {
//		
//	}
//	else if([elementName isEqualToString:@"feFlood"]) {
//		
//	}
//	else if([elementName isEqualToString:@"feBlend"]) {
//		
//	}
//	else if([elementName isEqualToString:@"feComposite"]) {
//		
//	}
	
	// Group node
	// -------------------------------------------------------------------------
	else if([elementName isEqualToString:@"g"]) {
		[curLayer release];
		curLayer = [[NSMutableDictionary alloc] init];
        [self copyDict:attrDict toDest:curLayer]; 
		
		self.curLayerName = currId;
		
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
	
		Sprite* currentSprite = [self currentSprite];
		if ([currentSprite isInitialized])
			currentSprite = nil;
        NSString *d = [attrDict valueForKey:@"d"];
        CFErrorRef error;
        currPath = CGPathCreateFromSVG([d UTF8String], &error);
        
		
        // set the current scale, in case there is no transform
        currentScaleX = globalScaleX;
        currentScaleY = globalScaleY;
		
		if([attrDict valueForKey:@"transform"]) {
			localTransform = [self applyTransformations:[attrDict valueForKey:@"transform"]];
		} 		
		// Respect the 'fill' attribute
		// TODO: This hex parsing stuff is in a bunch of places. It should be cetralized in a function instead.
		if([attrDict valueForKey:@"fill"]) {
			currentStyle.doFill = YES;
			currentStyle.fillType = @"solid";
			[currentStyle setFillColorFromAttribute:[attrDict valueForKey:@"fill"]];
		}
		
		currentStyle.styleString = [attrDict valueForKey:@"style"];
		
		if (currentSprite)
		{
			//transform to non-offset image coordinates
			CGAffineTransform temp = CGAffineTransformTranslate(transform, offsetX/currentScaleX, offsetY/currentScaleY);
			
			//scale down to relative image coordinates
			temp = CGAffineTransformConcat(temp, CGAffineTransformMakeScale(1.0/(globalScaleX*width),1.0/(globalScaleY*height) ));

			[currentSprite calcBoundingBox:CGPathGetBoundingBox(currPath) withTransform:temp];			
			[rootNode addSprite:currentSprite];
		}
        [self drawPath];

	}
	
	
	// Rect node
	// -------------------------------------------------------------------------
	else if([elementName isEqualToString:@"rect"]) {
		
		// Ignore rects in flow regions for now
		if(curFlowRegion)
			return;
		
	//Sprite* sprite =  [self currentSprite];
		
		float xPos = [[attrDict valueForKey:@"x"] floatValue];
		float yPos = [[attrDict valueForKey:@"y"] floatValue];
		float widthR = [[attrDict valueForKey:@"width"] floatValue];
		float heightR = [[attrDict valueForKey:@"height"] floatValue];
		float ry = [attrDict valueForKey:@"ry"]?[[attrDict valueForKey:@"ry"] floatValue]:-1.0;
		float rx = [attrDict valueForKey:@"rx"]?[[attrDict valueForKey:@"rx"] floatValue]:-1.0;
		
		if (ry==-1.0) ry = rx;
		if (rx==-1.0) rx = ry;
		
		 currPath = CGPathCreateMutable();
		CGPathAddRoundRect(currPath, CGRectMake(xPos,yPos ,widthR,heightR), rx);
		
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
		
		currentStyle.styleString = [attrDict valueForKey:@"style"];
        [self drawPath];

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
		
	//	Sprite* sprite =  [self currentSprite];

		
		NSCharacterSet *charset = [NSCharacterSet characterSetWithCharactersInString:@" \n"];
		
		// Extract the fill-rule attribute
	//	NSString* fill_rule = [attrDict valueForKey:@"fill-rule"];
		
		
		// Respect the 'fill' attribute
		// TODO: This hex parsing stuff is in a bunch of places. It should be cetralized in a function instead.
		if([attrDict valueForKey:@"fill"]) {
			currentStyle.doFill = YES;
			currentStyle.fillType = @"solid";
			[currentStyle setFillColorFromAttribute:[attrDict valueForKey:@"fill"]];
		}
		
		// Extract the points attribute and parse into a CGMutablePath
		 currPath = CGPathCreateMutable();
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
					CGPathMoveToPoint(currPath, NULL, x, y);
				}
				else
				{
					CGPathAddLineToPoint(currPath, NULL, x, y);
				}
			}
		}
		currentStyle.styleString = [attrDict valueForKey:@"style"];
        [self drawPath];
		
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
		float widthI = [[attrDict valueForKey:@"width"] floatValue];
		float heightI = [[attrDict valueForKey:@"height"] floatValue];
		
	
		if([attrDict valueForKey:@"transform"]) {
			[self applyTransformations:[attrDict valueForKey:@"transform"]];
		} 
		
		yPos-=heightI/2;
		CGImageRef theImage = imageFromBase64([attrDict valueForKey:@"xlink:href"]);
		CGAffineTransform flipVertical = CGAffineTransformMake(1, 0, 0, -1, 0, heightI);
		CGContextConcatCTM(cgContext, flipVertical);
		CGContextDrawImage(cgContext, CGRectMake(xPos, yPos, widthI, heightI), theImage);
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
        if (delegate)
		    [delegate svgRenderer:self finishedRenderingInCGContext:cgContext];
		[self cleanupAfterFinishedParsing];
	}
	
	else if([elementName isEqualToString:@"g"]) {
		self.curLayerName = nil;
	}
	
	else if([elementName isEqualToString:@"defs"]) {
		inDefSection = NO;
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

-(Sprite*) currentSprite
{
	if (!currId || ![curLayerName isEqualToString:@"location_overlay"] )
		return nil;
			
	
	NSObject* obj = [sprites objectForKey:currId];
	if (!obj)
	{
		Sprite* sprite = [Sprite new];
		sprite.name = currId;
		[sprites setObject:sprite forKey:currId];
		[sprite release];		
	}
	return (Sprite*)[sprites objectForKey:currId];

	
	
}

-(void) drawPath
{
    
    [self drawPath:currPath withStyle:currentStyle];
    
    PathFrag* frag = [[PathFrag alloc] init:self];
    [frag wrap:currPath style:currentStyle transform:localTransform.transform type:localTransform.type];
    [currentStyle release];
    currentStyle = [SVGStyle new];
    [fragments addObject:frag];
    Sprite* currentSprite = [self currentSprite];
    if (currentSprite)
        currentSprite.frag = frag;
    [frag release];

}
// Draw a path based on style information
// -----------------------------------------------------------------------------
- (void)drawPath:(CGPathRef)path withStyle:(SVGStyle*)style
{		
	CGContextSaveGState(cgContext);
	if(style.styleString)
		[style setStyleContext:currentStyle.styleString withDefDict:defDict];
	
	Sprite* info = (Sprite*)[sprites objectForKey:currId];
    style.isHighlighted = info.isHighlighted;	
    [style drawPath:path withContext:cgContext];	

	CGContextRestoreGState(cgContext);
	
}

- (SVG_TRANS)applyTransformations:(NSString *)transformations
{    
        
    
    float a=1;
    float b=0;
    float c=0;
    float d=1;
    float tx=0;
    float ty=0;
    BOOL hasMatrix = NO, hasScale = NO, hasRotate = NO, hasTrans = NO;
    enum TRANSFORMATION_TYPE type;
    
    const char* s = [transformations UTF8String];
    if (strncmp(s,"matrix",strlen("matrix")-1) == 0)
    {
        int scanned = sscanf(s,"matrix(%f,%f,%f,%f,%f,%f)",&a,&b,&c,&d,&tx,&ty);
        if (scanned == 6)
        {
          hasMatrix = YES;
           type = AFFINE;
        }
        else
        {
            NSLog(@"Error scanning matrix tranform");
        }
        
    }
    else if (strncmp(s,"scale",strlen("scale")-1) == 0)
    {
        int scanned = sscanf(s,"scale(%f,%f)",&a,&d);
        if (scanned == 2)
        {
           hasScale = YES;
           type = SCALE;
        }
        else
        {
            NSLog(@"Error scanning scale tranform"); 
        }
    } 
    else if (strncmp(s,"translate",strlen("translate")-1) == 0)
    {
        int scanned =  sscanf(s,"translate(%f,%f)",&tx,&ty);
        if (scanned == 2)
        {
           hasTrans = YES;
           type = TRANS;
        }
        else
        {
            NSLog(@"Error scanning matrix tranform");
        }
    } 
    else if (strncmp(s,"rotate",strlen("rotate")-1) == 0)
    {
        int scanned = sscanf(s,"rotate(%f)",&a);
        if (scanned == 1)
        {
            hasRotate = YES;
            type = ROT;
        }
        else
        {
            NSLog(@"Error scanning rotate tranform");
        }
    }  
    

    
    SVG_TRANS localTransformation;
    localTransformation.transform = CGAffineTransformMake(a,b,c,d,tx,ty);
    localTransformation.type = type;
    [self applyTransformation:localTransformation];  
    
    return localTransformation;
    
}

- (void)applyTransformation:(SVG_TRANS)trans
{
    currentScaleX = globalScaleX;
	currentScaleY = globalScaleY;
    
	CGContextConcatCTM(cgContext,CGAffineTransformInvert(transform));
	transform = CGAffineTransformIdentity;
    
    float a = trans.transform.a;
    float b = trans.transform.b;
    float c = trans.transform.c;
    float d = trans.transform.d;
    float tx = trans.transform.tx;
    float ty = trans.transform.ty;

    
	// Matrix
	if (trans.type == AFFINE)
	{	
        
        // local translation, with correction for global scale, and global offset	
        tx = tx*globalScaleX - offsetX;
        ty = ty*globalScaleY - offsetY;
        
        // transfer all scaling to single transformation
        currentScaleX *= a;
        currentScaleY *= d;
        
        a = 1;
        b /= d;
        c /= a;
        d = 1;
        
        //move all scaling into separate transformation
        if (currentScaleX != 1.0 || currentScaleY != 1.0)
            transform = CGAffineTransformMakeScale(currentScaleX, currentScaleY);
        
        
        CGAffineTransform matrixTransform = CGAffineTransformMake (a,b,c,d, tx, ty);
        
        transform = CGAffineTransformConcat(transform, matrixTransform);
        
        
        // Apply to graphics context
        CGContextConcatCTM(cgContext,transform);
        
        return;
        
		
	}
	
	
	// Scale
	if (trans.type == SCALE)
	{			
        currentScaleX *= a;
        currentScaleY *= d;		
        
	}
	if (currentScaleX != 1.0 || currentScaleY != 1.0)
		transform = CGAffineTransformScale(transform, currentScaleX, currentScaleY);
	
	
	// Rotate
	if ( (trans.type == ROT) && a != 0)
	{
        transform = CGAffineTransformRotate(transform, a);		
	}
    
	
	// Translate
	float transX = -offsetX/currentScaleX;
	float transY = -offsetY/currentScaleY;
    
	if (trans.type == TRANS)
	{	
        transX += tx;
        transY += ty;								
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



void CGPathAddRoundRect(CGMutablePathRef currPath, CGRect rect, float radius)
{
	CGPathMoveToPoint(currPath, NULL, rect.origin.x, rect.origin.y + radius);
	
	CGPathAddLineToPoint(currPath, NULL, rect.origin.x, rect.origin.y + rect.size.height - radius);
	CGPathAddArc(currPath, NULL, rect.origin.x + radius, rect.origin.y + rect.size.height - radius, 
					radius, M_PI / 1, M_PI / 2, 1);
	
	CGPathAddLineToPoint(currPath, NULL, rect.origin.x + rect.size.width - radius, 
							rect.origin.y + rect.size.height);
	CGPathAddArc(currPath, NULL, rect.origin.x + rect.size.width - radius, 
					rect.origin.y + rect.size.height - radius, radius, M_PI / 2, 0.0f, 1);
	
	CGPathAddLineToPoint(currPath, NULL, rect.origin.x + rect.size.width, rect.origin.y + radius);
	CGPathAddArc(currPath, NULL, rect.origin.x + rect.size.width - radius, rect.origin.y + radius, 
					radius, 0.0f, -M_PI / 2, 1);
	
	CGPathAddLineToPoint(currPath, NULL, rect.origin.x + radius, rect.origin.y);
	CGPathAddArc(currPath, NULL, rect.origin.x + radius, rect.origin.y + radius, radius, 
					-M_PI / 2, M_PI, 1);
}

- (void)dealloc
{
	[self cleanupAfterFinishedParsing];
	[xmlParser release];
	[sprites release];
    
    [fragments release];
	[rootNode release];
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
/////////////////////////////////////////////////////////

#pragma mark SAX Parsing Callbacks

/*
 This callback is invoked when the parser finds the beginning of a node in the XML. For this application,
 out parsing needs are relatively modest - we need only match the node name. An "item" node is a record of
 data about a song. In that case we create a new Song object. The other nodes of interest are several of the
 child nodes of the Song currently being parsed. For those nodes we want to accumulate the character data
 in a buffer. Some of the child nodes use a namespace prefix. 
 */
static void startElementSAX(void *ctx, const xmlChar *localname, const xmlChar *prefix, const xmlChar *URI, 
                            int nb_namespaces, const xmlChar **namespaces, int nb_attributes, int nb_defaulted, const xmlChar **attributes) {
    SVGQuartzRenderer *parser = (SVGQuartzRenderer *)ctx;

/*    
    printf( "startElementNs: name = '%s' prefix = '%s' uri = (%p)'%s'\n", localname, prefix, URI, URI );
    for ( int indexNamespace = 0; indexNamespace < nb_namespaces; ++indexNamespace )
    {
        const xmlChar *prefix = namespaces[indexNamespace*2];
        const xmlChar *nsURI = namespaces[indexNamespace*2+1];
        printf( "  namespace: name='%s' uri=(%p)'%s'\n", prefix, nsURI, nsURI );
    }
    
    unsigned int index = 0;
    for ( int indexAttribute = 0; 
         indexAttribute < nb_attributes; 
         ++indexAttribute, index += 5 )
    {
        const xmlChar *localname = attributes[index];
        const xmlChar *prefix = attributes[index+1];
        const xmlChar *nsURI = attributes[index+2];
        const xmlChar *valueBegin = attributes[index+3];
        const xmlChar *valueEnd = attributes[index+4];
        int vlen = valueEnd - valueBegin;
        unsigned char val[vlen + 1];
        strncpy(val, valueBegin, vlen);
        val[vlen] = '\0';
        printf( "  %sattribute: localname='%s', prefix='%s', uri=(%p)'%s', value='%s'\n",
               indexAttribute >= (nb_attributes - nb_defaulted) ? "defaulted " : "",
               localname,
               prefix,
               nsURI,
               nsURI,
               val);
    }
 */
    
}

/*
 This callback is invoked when the parse reaches the end of a node. At that point we finish processing that node,
 if it is of interest to us. For "item" nodes, that means we have completed parsing a Song object. We pass the song
 to a method in the superclass which will eventually deliver it to the delegate. For the other nodes we
 care about, this means we have all the character data. The next step is to create an NSString using the buffer
 contents and store that with the current Song object.
 */
static void	endElementSAX(void *ctx, const xmlChar *localname, const xmlChar *prefix, const xmlChar *URI) {    
    SVGQuartzRenderer *parser = (SVGQuartzRenderer *)ctx;
  //  printf( "endElementNs: name = '%s' prefix = '%s' uri = '%s'\n", localname, prefix, URI );
    

}

/*
 This callback is invoked when the parser encounters character data inside a node. The parser class determines how to use the character data.
 */
static void	charactersFoundSAX(void *ctx, const xmlChar *ch, int len) {
    SVGQuartzRenderer *parser = (SVGQuartzRenderer *)ctx;

}

/*
 A production application should include robust error handling as part of its parsing implementation.
 The specifics of how errors are handled depends on the application.
 */
static void errorEncounteredSAX(void *ctx, const char *msg, ...) {
    // Handle errors as appropriate for your application.
    NSCAssert(NO, @"Unhandled error encountered during SAX parse.");
    va_list args;
    va_start(args, msg);
    vprintf( msg, args );
    va_end(args);
}

// The handler struct has positions for a large number of callback functions. If NULL is supplied at a given position,
// that callback functionality won't be used. Refer to libxml documentation at http://www.xmlsoft.org for more information
// about the SAX callbacks.
static xmlSAXHandler simpleSAXHandlerStruct = {
    NULL,                       /* internalSubset */
    NULL,                       /* isStandalone   */
    NULL,                       /* hasInternalSubset */
    NULL,                       /* hasExternalSubset */
    NULL,                       /* resolveEntity */
    NULL,                       /* getEntity */
    NULL,                       /* entityDecl */
    NULL,                       /* notationDecl */
    NULL,                       /* attributeDecl */
    NULL,                       /* elementDecl */
    NULL,                       /* unparsedEntityDecl */
    NULL,                       /* setDocumentLocator */
    NULL,                       /* startDocument */
    NULL,                       /* endDocument */
    NULL,                       /* startElement*/
    NULL,                       /* endElement */
    NULL,                       /* reference */
    charactersFoundSAX,         /* characters */
    NULL,                       /* ignorableWhitespace */
    NULL,                       /* processingInstruction */
    NULL,                       /* comment */
    NULL,                       /* warning */
    errorEncounteredSAX,        /* error */
    NULL,                       /* fatalError //: unused error() get all the errors */
    NULL,                       /* getParameterEntity */
    NULL,                       /* cdataBlock */
    NULL,                       /* externalSubset */
    XML_SAX2_MAGIC,             //
    NULL,
    startElementSAX,            /* startElementNs */
    endElementSAX,              /* endElementNs */
    NULL,                       /* serror */
};
#pragma mark

@end
