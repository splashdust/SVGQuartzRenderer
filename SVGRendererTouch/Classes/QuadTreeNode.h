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
@private
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
- (NSArray *)groupContainingPoint:(CGPoint)point;
- (int)numberOfLeafNodes;

@end
