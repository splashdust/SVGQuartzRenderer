//
//  SVGQuartzRenderer.h
//  SVGRender
//
//  Created by Joacim Magnusson on 2010-09-23.
//  Copyright 2010 Joacim Magnusson. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol SVGQuartzRenderDelegate

	- (void)svgRenderer:(id<SVGQuartzRenderDelegate>)renderer
			didFinnishRenderingFile:(NSString *)file;

	- (CGContextRef)svgRenderer:(id)renderer
					requestedCGContextWidthSize:(CGSize)size;

@end


@interface SVGQuartzRenderer : NSObject <NSXMLParserDelegate> {
	CGSize documentSize;
	id<SVGQuartzRenderDelegate> delegate;
	CGFloat scale;
}

@property (readonly) CGSize documentSize;
@property (readonly) id delegate;
@property (readwrite) CGFloat scale;

- (void)drawSVGFile:(NSString *)file;
- (void)setDelegate:(id<SVGQuartzRenderDelegate>)rendererDelegate;
- (CGContextRef)createBitmapContext;

@end
