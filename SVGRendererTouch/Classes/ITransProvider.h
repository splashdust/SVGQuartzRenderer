//
//  ITransProvider.h
//  SVGRendererTouch
//
//  Created by Aaron Boxer on 11-04-21.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>


@protocol ITransProvider <NSObject>
-(CGPoint) getTranslation;
-(CGPoint) getScale;
@end
