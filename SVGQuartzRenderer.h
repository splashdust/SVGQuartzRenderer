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

#import <Foundation/Foundation.h>
#import "ITransProvider.h"
#import "GraphicFrag.h"
#import <libxml/tree.h>

@class Sprite;
@class SVGStyle;
@class QuadTreeNode;

@protocol SVGQuartzRenderDelegate
	- (void)svgRenderer:(id)renderer finishedRenderingInCGContext:(CGContextRef)context;
	- (CGContextRef)svgRenderer:(id)renderer requestedCGContextWithSize:(CGSize)size;
@end


@interface SVGQuartzRenderer : NSObject <ITransProvider> {
@private
	CGSize documentSize;
	id<SVGQuartzRenderDelegate> delegate;
	CGFloat globalScaleX;
	CGFloat globalScaleY;
	CGFloat currentScaleX;
	CGFloat currentScaleY;
	CGFloat offsetX;
	CGFloat offsetY;
	CGRect viewFrame;
	float initialScaleX ;
	float initialScaleY ;
	float width;
	float height;	
	
    // Reference to the libxml parser context
    xmlParserCtxtPtr context;
	NSData *svgXml;
    NSString* svgFile;
	CGAffineTransform transform;
    SVG_TRANS localTransform;
	CGContextRef cgContext;
	
	BOOL firstRender;
	NSMutableDictionary *defDict;
		
	NSMutableDictionary *curPat;
	NSMutableDictionary *curGradient;
	NSMutableDictionary *curFilter;
	NSMutableDictionary *curLayer;
	NSString* curLayerName;
	NSDictionary *curText;
	NSDictionary *curFlowRegion;
    
	SVGStyle* currentStyle;	    
	CGPathRef currPath;
	NSString* currId;	
	BOOL inDefSection;	
    
	NSMutableArray* fragments;
	NSMutableDictionary* sprites;
	QuadTreeNode* rootNode;
}

@property (readonly) CGSize documentSize;
@property (readonly) id<SVGQuartzRenderDelegate> delegate;
@property (readwrite) CGFloat globalScaleX;
@property (readwrite) CGFloat globalScaleY;
@property (readwrite) CGFloat offsetX;
@property (readwrite) CGFloat offsetY;
@property (readwrite) CGRect viewFrame;
@property (readwrite, copy) NSString* curLayerName;

- (void) resetScale;

- (void)parse:(NSString *)file;
-(void) redraw;
- (void)setDelegate:(id<SVGQuartzRenderDelegate>)rendererDelegate;
- (CGContextRef)createBitmapContext;
-(CGPoint) scaledImagePointFromViewPoint:(CGPoint)viewPoint;
-(void) center:(CGPoint)location withBoundingBox:(CGSize)box;
-(NSString*) find:(CGPoint)viewPoint;

@end
