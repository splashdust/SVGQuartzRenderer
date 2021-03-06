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

#import <UIKit/UIKit.h>
#import "SVGQuartzRenderer.h"

@protocol SVGRenderViewTouchDelegate
  - (void) doubleTap:(NSString*)location;
  - (void) singleTap:(NSString*)location;
@end


@interface SVGRenderViewTouch : UIView <SVGQuartzRenderDelegate> {
@private
	id<SVGRenderViewTouchDelegate> delegate;
	CGPoint origin;
	CGImageRef svgDrawing;
	CGFloat initialDistance;
	CGPoint initialPoint;
	CGFloat initialScaleX;
	CGFloat initialScaleY;
	BOOL panning;
	NSMutableArray* svgRenderers;
    int currentRenderer;
	NSString* selectedLocation;
	CALayer* svgLayer;
    
    UIActivityIndicatorView* spinner;
}

-(void) open;
-(void) render;
-(void) locate:(CGPoint)location withBoundingBox:(CGSize)box;
-(void) setDelegate:(id<SVGRenderViewTouchDelegate>)del;

-(void) nextRenderer;
-(void) previousRenderer;

@property (nonatomic, copy) NSString* selectedLocation;

@end
