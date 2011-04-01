//
//  Sprite.h
//  SVGRendererTouch
//
//  Created by Aaron Boxer on 11-03-31.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface Sprite : NSObject
{
@public
    CGRect boundingRect;
	BOOL isHighlighted;

}
@property (nonatomic) BOOL isHighlighted;

@end

