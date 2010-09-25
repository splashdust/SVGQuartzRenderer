//
//  SVGQuartzRenderer.h
//  SVGRender
//
//  Created by Joacim Magnusson on 2010-09-23.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface SVGQuartzRenderer : NSObject <NSXMLParserDelegate> {

}

- (void)drawSVGFile:(NSString *)file inCGContext:(CGContextRef)context;

@end
