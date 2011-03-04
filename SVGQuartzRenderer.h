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

@protocol SVGQuartzRenderDelegate

	- (void)svgRenderer:(id)renderer
didFinishRenderingFile:(NSString *)file
			inCGContext:(CGContextRef)context;

	- (CGContextRef)svgRenderer:(id)renderer
	requestedCGContextWithSize:(CGSize)size;

@end


@interface SVGQuartzRenderer : NSObject <NSXMLParserDelegate> {
	CGSize documentSize;
	id<SVGQuartzRenderDelegate> delegate;
	CGFloat scaleX;
	CGFloat scaleY;
	CGFloat offsetX;
	CGFloat offsetY;
	CGRect viewFrame;
}

@property (readonly) CGSize documentSize;
@property (readonly) id delegate;
@property (readwrite) CGFloat scaleX;
@property (readwrite) CGFloat scaleY;
@property (readwrite) CGFloat offsetX;
@property (readwrite) CGFloat offsetY;
@property (readwrite) CGRect viewFrame;

- (void)drawSVGFile:(NSString *)file;
- (void)setDelegate:(id<SVGQuartzRenderDelegate>)rendererDelegate;
- (CGContextRef)createBitmapContext;

@end
