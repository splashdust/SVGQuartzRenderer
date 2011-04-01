//
//  QuadTreeNode.h
//  SVGRendererTouch
//
//  Created by Aaron Boxer on 11-03-31.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Sprite.h"



#define MAX_NODE_CAPACITY   10


@interface QuadTreeNode : NSObject
{
    CGRect rect;
    NSMutableArray *sprites;
    BOOL isLeaf;
    QuadTreeNode *children[2][2];
    int childWidth, childHeight;
}
- (id)initWithRect:(CGRect)r;
- (void)addSprite:(Sprite *)sprite;
- (void)removeSprite:(Sprite *)sprite;
- (NSArray *)groupContainingSprite:(Sprite *)sprite;
- (int)numberOfLeafNodes;

@end
