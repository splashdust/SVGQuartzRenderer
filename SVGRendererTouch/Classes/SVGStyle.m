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
    -(BOOL) parseStyle:(char*)keyBegin :(char*)keyEnd :(char*)valueBegin :(char*)valueEnd :(NSDictionary*)defDict;
    -(BOOL) parseStyle:(NSString*)attrName :(NSString*)attrValue :(NSDictionary*)defDict;

@end

@implementation SVGStyle

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
@synthesize isHighlighted;

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
	another.fillColor = fillColor;
	another.fillOpacity = fillOpacity;
	another.doStroke = doStroke;
	another.strokeColor = strokeColor ;
	another.strokeWidth = strokeWidth;
	another.strokeOpacity = strokeOpacity;
	another.lineJoinStyle = lineJoinStyle;
	another.lineCapStyle = lineCapStyle;
	another.miterLimit = miterLimit;
	another.fillPattern = CGPatternRetain(fillPattern);
	another.fillType = fillType;
	another.fillGradient = CGGradientRetain(fillGradient);
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
    [font release];
	font = nil;
	CGGradientRelease(fillGradient);
	fillGradient = NULL;
	CGPatternRelease(fillPattern);
	fillPattern = NULL;
}

-(BOOL) parseStyle:(char*)keyBegin :(char*)keyEnd :(char*)valueBegin :(char*)valueEnd :(NSDictionary*)defDict
{
    size_t length = keyEnd-keyBegin + 1;
    BOOL rc = NO;
   if (strncmp(keyBegin, "fill", length) == 0)
   {
       doFill = YES;
       fillType = @"solid";
       unsigned int colour;
       valueBegin++; //skip # 
       int vlen = valueEnd - valueBegin+1;
       char val[vlen + 1];
       strncpy(val, (const char*)valueBegin, vlen);
       val[vlen] = '\0';
       colour = strtoul(valueBegin,NULL, 16); 
       [self setFillColorFromInt:colour];
       rc = YES;
       
   } else if (strncmp(keyBegin, "fill-opacity",length ) == 0)
   {
       int vlen = valueEnd - valueBegin+1;
       char val[vlen + 1];
       strncpy(val, (const char*)valueBegin, vlen);
       val[vlen] = '\0';
       fillColor.a = atof(val); 
       rc = YES;
       
   }
   if (!rc)
   {
       NSString* attrName = [[NSString alloc] initWithBytes:keyBegin length:keyEnd-keyBegin+1 encoding:NSASCIIStringEncoding];
       NSString* attrValue = [[NSString alloc] initWithBytes:valueBegin length:valueEnd-valueBegin+1 encoding:NSASCIIStringEncoding];  
       rc = [self parseStyle:attrName :attrValue :defDict];
       [attrName release];
       [attrValue release];
       
   }
    return rc;
}

-(BOOL) parseStyle:(NSString*)attrName :(NSString*)attrValue :(NSDictionary*)defDict
{
    BOOL rc = NO;
   	
    // --------------------- FILL
    if([attrName isEqualToString:@"fill"]) {
         if([attrValue rangeOfString:@"url"].location != NSNotFound) {
            
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
                                                   &desc,
                                                   desc.rect,
                                                   CGAffineTransformIdentity,
                                                   desc.rect.size.width,
                                                   desc.rect.size.height,
                                                   kCGPatternTilingConstantSpacing,
                                                   true,
                                                   &callbacks);
                    
                    
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
                    CGColorSpaceRef colourSpace = CGColorSpaceCreateDeviceRGB();
                    fillGradient = CGGradientCreateWithColorComponents(colourSpace,
                                                                       colors, 
                                                                       locations,
                                                                       [stops count]);
                    CGColorSpaceRelease(colourSpace);
                }
            }
        } else {
            doFill = NO;
        }
        
    }
    
    // --------------------- STROKE
    else if([attrName isEqualToString:@"stroke"]) {
        if(![attrValue isEqualToString:@"none"]) {
            doStroke = YES;
            strokeColor = [SVGStyle extractColorFromAttribute:attrValue];
            strokeWidth = 1;
        } else {
            doStroke = NO;
        }
        
    }
    
    // --------------------- STROKE-OPACITY
    else if([attrName isEqualToString:@"stroke-opacity"]) {
        NSScanner *floatScanner = [NSScanner scannerWithString:attrValue];
        [floatScanner scanFloat:&strokeOpacity];
    }
    
    // --------------------- STROKE-WIDTH
    else if([attrName isEqualToString:@"stroke-width"]) {
        NSScanner *floatScanner = [NSScanner scannerWithString:
                                   [attrValue stringByReplacingOccurrencesOfString:@"px" withString:@""]];
        [floatScanner scanFloat:&strokeWidth];
        
    }
    
    // --------------------- STROKE-LINECAP
    else if([attrName isEqualToString:@"stroke-linecap"]) {
        NSScanner *stringScanner = [NSScanner scannerWithString:attrValue];
        NSString *lineCapValue;
        [stringScanner scanUpToString:@";" intoString:&lineCapValue];
        
        if([lineCapValue isEqualToString:@"butt"])
            lineCapStyle = kCGLineCapButt;
        
        else if([lineCapValue isEqualToString:@"round"])
            lineCapStyle = kCGLineCapRound;
        
        else if([lineCapValue isEqualToString:@"square"])
            lineCapStyle = kCGLineCapSquare;
    }
    
    // --------------------- STROKE-LINEJOIN
    else if([attrName isEqualToString:@"stroke-linejoin"]) {
        NSScanner *stringScanner = [NSScanner scannerWithString:attrValue];
        NSString *lineCapValue;
        [stringScanner scanUpToString:@";" intoString:&lineCapValue];
        
        if([lineCapValue isEqualToString:@"miter"])
            lineJoinStyle = kCGLineJoinMiter;
        
        else if([lineCapValue isEqualToString:@"round"])
            lineJoinStyle = kCGLineJoinRound;
        
        else if([lineCapValue isEqualToString:@"bevel"])
            lineJoinStyle = kCGLineJoinBevel;
    }
    
    // --------------------- STROKE-MITERLIMIT
    else if([attrName isEqualToString:@"stroke-miterlimit"]) {
        NSScanner *floatScanner = [NSScanner scannerWithString:attrValue];
        [floatScanner scanFloat:&miterLimit];
    }
    // --------------------- FONT-SIZE
    else if([attrName isEqualToString:@"font-size"]) {
        NSScanner *floatScanner = [NSScanner scannerWithString:attrValue];
        [floatScanner scanFloat:&fontSize];
    }
    
    // --------------------- FONT-STYLE
    else if([attrName isEqualToString:@"font-style"]) {
        
    }
    
    // --------------------- FONT-WEIGHT
    else if([attrName isEqualToString:@"font-weight"]) {
        
    }
    
    // --------------------- LINE-HEIGHT
    else if([attrName isEqualToString:@"line-height"]) {
        
    }
    
    // --------------------- LETTER-SPACING
    else if([attrName isEqualToString:@"letter-spacing"]) {
        
    }
    
    // --------------------- WORD-SPACING
    else if([attrName isEqualToString:@"word-spacing"]) {
        
    }
    
    // --------------------- FONT-FAMILY
    else if([attrName isEqualToString:@"font-family"]) {
        font = [attrValue retain];
        if([font isEqualToString:@"Sans"])
            font = @"Helvetica";
    } 
    
    return rc;
    
    
}

- (void)setStyleContext:(char*)styleString withDefDict:(NSDictionary*)defDict
{
    
    char* styleBegin = styleString;
    char* styleEnd = styleString;
    char* styleColon = 0;
    char* final = styleString + strlen(styleString);
    char ch = *styleBegin;
    bool newLine = false;
    while (styleEnd <= final)
    {   
        //parse final line
        if (styleEnd == final)
        {
            [self parseStyle:styleBegin :styleColon-1 :styleColon+1 :styleEnd :defDict];
            break;
        }
        
        ch = *styleEnd;
        switch(ch)
        {
         case ':':
                styleColon = styleEnd;
                break;
         case ';':
                //parse line
                [self parseStyle:styleBegin :styleColon-1 :styleColon+1 :styleEnd :defDict];
                newLine = true;                
                break;
        default:
                if (newLine )
                {
                    if (ch != '\n')
                    {
                        styleBegin = styleEnd;
                        styleColon = 0;
                        newLine = false;
                    }
                }  
                break;                
        }
        styleEnd++;   
            
    }
}

    /*
    
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
                NSLog(attrValue);
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
																			&desc,
																		desc.rect,
																		CGAffineTransformIdentity,
																		desc.rect.size.width,
																		desc.rect.size.height,
																		kCGPatternTilingConstantSpacing,
																		true,
																		&callbacks);
						
						
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
                        CGColorSpaceRef colourSpace = CGColorSpaceCreateDeviceRGB();
						fillGradient = CGGradientCreateWithColorComponents(colourSpace,
																						colors, 
																						locations,
																						[stops count]);
                        CGColorSpaceRelease(colourSpace);
					}
				}
			} else {
				doFill = NO;
			}
			
		}
		
		// --------------------- FILL-OPACITY
		else if([attrName isEqualToString:@"fill-opacity"]) {
			NSScanner *floatScanner = [NSScanner scannerWithString:attrValue];
			[floatScanner scanFloat:&fillColor.a];
		}
		
		// --------------------- STROKE
		else if([attrName isEqualToString:@"stroke"]) {
			if(![attrValue isEqualToString:@"none"]) {
				doStroke = YES;
				strokeColor = [SVGStyle extractColorFromAttribute:attrValue];
				strokeWidth = 1;
			} else {
				doStroke = NO;
			}
			
		}
		
		// --------------------- STROKE-OPACITY
		else if([attrName isEqualToString:@"stroke-opacity"]) {
			NSScanner *floatScanner = [NSScanner scannerWithString:attrValue];
			[floatScanner scanFloat:&strokeOpacity];
		}
		
		// --------------------- STROKE-WIDTH
		else if([attrName isEqualToString:@"stroke-width"]) {
			NSScanner *floatScanner = [NSScanner scannerWithString:
									   [attrValue stringByReplacingOccurrencesOfString:@"px" withString:@""]];
			[floatScanner scanFloat:&strokeWidth];
			
		}
		
		// --------------------- STROKE-LINECAP
		else if([attrName isEqualToString:@"stroke-linecap"]) {
			NSScanner *stringScanner = [NSScanner scannerWithString:attrValue];
			NSString *lineCapValue;
			[stringScanner scanUpToString:@";" intoString:&lineCapValue];
			
			if([lineCapValue isEqualToString:@"butt"])
				lineCapStyle = kCGLineCapButt;
			
			else if([lineCapValue isEqualToString:@"round"])
				lineCapStyle = kCGLineCapRound;
			
			else if([lineCapValue isEqualToString:@"square"])
				lineCapStyle = kCGLineCapSquare;
		}
		
		// --------------------- STROKE-LINEJOIN
		else if([attrName isEqualToString:@"stroke-linejoin"]) {
			NSScanner *stringScanner = [NSScanner scannerWithString:attrValue];
			NSString *lineCapValue;
			[stringScanner scanUpToString:@";" intoString:&lineCapValue];
			
			if([lineCapValue isEqualToString:@"miter"])
				lineJoinStyle = kCGLineJoinMiter;
			
			else if([lineCapValue isEqualToString:@"round"])
				lineJoinStyle = kCGLineJoinRound;
			
			else if([lineCapValue isEqualToString:@"bevel"])
				lineJoinStyle = kCGLineJoinBevel;
		}
		
		// --------------------- STROKE-MITERLIMIT
		else if([attrName isEqualToString:@"stroke-miterlimit"]) {
			NSScanner *floatScanner = [NSScanner scannerWithString:attrValue];
			[floatScanner scanFloat:&miterLimit];
		}
		// --------------------- FONT-SIZE
		else if([attrName isEqualToString:@"font-size"]) {
			NSScanner *floatScanner = [NSScanner scannerWithString:attrValue];
			[floatScanner scanFloat:&fontSize];
		}
		
		// --------------------- FONT-STYLE
		else if([attrName isEqualToString:@"font-style"]) {
			
		}
		
		// --------------------- FONT-WEIGHT
		else if([attrName isEqualToString:@"font-weight"]) {
			
		}
		
		// --------------------- LINE-HEIGHT
		else if([attrName isEqualToString:@"line-height"]) {
			
		}
		
		// --------------------- LETTER-SPACING
		else if([attrName isEqualToString:@"letter-spacing"]) {
			
		}
		
		// --------------------- WORD-SPACING
		else if([attrName isEqualToString:@"word-spacing"]) {
			
		}
		
		// --------------------- FONT-FAMILY
		else if([attrName isEqualToString:@"font-family"]) {
			font = [attrValue retain];
			if([font isEqualToString:@"Sans"])
				font = @"Helvetica";
		}
		
		[cssScanner scanString:@";" intoString:nil];
	}
    
    
    
    
    
    
	[pool release];
     */


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
		
		else if([linkedDef objectForKey:@"stops"])
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
- (void)drawPath:(CGPathRef)path withContext:(CGContextRef)context
{				
	if(doFill) {
        FILL_COLOR oldColour = fillColor;
        if (isHighlighted)
            [self setFillColorFromInt:0x00FF0000]; 
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
        if (isHighlighted)
            fillColor = oldColour;
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
	[self reset];
	[super dealloc];
}

@end
