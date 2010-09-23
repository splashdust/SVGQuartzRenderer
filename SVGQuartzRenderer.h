//
//  SVGQuartzRenderer.h
//  SVGRender
//
//  Created by Joacim Magnusson on 2010-09-23.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface SVGQuartzRenderer : NSObject {
	NSXMLParser* xmlParser;
	NSAffineTransform *transform;
	NSAffineTransform *identity;
	CGSize documentSize;
	NSImage *canvas;
	NSView *view;
}

- (NSImage *)imageFromSVGFile:(NSString *)file view:(NSView *)view;

@end
