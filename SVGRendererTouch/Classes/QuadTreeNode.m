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
//  QuadTreeNode.m
//  SVGRendererTouch
//


#import "QuadTreeNode.h"
#import "Sprite.h"

@implementation QuadTreeNode

- (id)initWithRect:(CGRect)r
{
    [super init];
    rect = r;
    isLeaf = YES;
    sprites = [[NSMutableArray alloc] init];
    return self;
}

- (void)dealloc
{
    [sprites release];
    // Is this wise? yes!!!
    [children[0][0] release];
    [children[0][1] release];
    [children[1][0] release];
    [children[1][1] release];
    [super dealloc];
}

- (void)addSprite:(Sprite *)sprite
{
    if (isLeaf) {
		[sprites addObject:sprite];
		if ([sprites count] > MAX_NODE_CAPACITY) {
			isLeaf = NO;
			childWidth = rect.size.width / 2;
			childHeight = rect.size.height / 2;
			int i = [sprites count];
			while (i--) {
				[self addSprite:[sprites objectAtIndex:i]];
			}
			[sprites release];
			sprites = nil;
		}
    } else {
		BOOL visited[2][2] = {{NO,NO},{NO,NO}};
		float x,y;
		int i, j,xIndex, yIndex;
		// Loop through the (x,y) coordinates of the four corners
		// of the sprite's bounding rectangle.
		for (i = 0; i < 2; i++) {
			x = sprite->boundingRect.origin.x + i*sprite->boundingRect.size.width;
			xIndex = (x - rect.origin.x) / childWidth;
			if (xIndex < 0 || xIndex > 1) continue;
			
			for (j = 0; j < 2; j++) {
				y = sprite->boundingRect.origin.y + j*sprite->boundingRect.size.height;
				yIndex = (y - rect.origin.y) / childHeight;
				if (yIndex < 0 || yIndex > 1) continue;
				
				// Make sure we haven't already added the sprite to this child.
				if (!visited[xIndex][yIndex]) {
					// Initialize the child node if necessary.
					if (children[xIndex][yIndex] == nil) {
						CGRect r;
						r.origin.x = rect.origin.x + xIndex*childWidth;
						r.origin.y = rect.origin.y + yIndex*childHeight;
						r.size.width = childWidth;
						r.size.height = childHeight;
						children[xIndex][yIndex] = [[QuadTreeNode alloc] initWithRect:r];
					}
					[children[xIndex][yIndex] addSprite:sprite];
					visited[xIndex][yIndex] = YES;
				}
			} // end for j
		} // end for i
    } // end else is not leaf
}

- (void)removeSprite:(Sprite *)sprite
{
    if (isLeaf) {
		[sprites removeObjectIdenticalTo:sprite];
    } else {
		BOOL visited[2][2] = {{NO,NO},{NO,NO}};
		int i, j, x, y, xIndex, yIndex;
		// Loop through the (x,y) coordinates of the four corners
		// of the sprite's bounding rectangle.
		for (i = 0; i < 2; i++) {
			x = sprite->boundingRect.origin.x + i*sprite->boundingRect.size.width;
			xIndex = (x - rect.origin.x) / childWidth;
			if (xIndex < 0 || xIndex > 1) continue;
			
			for (j = 0; j < 2; j++) {
				y = sprite->boundingRect.origin.y + j*sprite->boundingRect.size.height;
				yIndex = (y - rect.origin.y) / childHeight;
				if (yIndex < 0 || yIndex > 1) continue;
				
				// Make sure we haven't already removed the sprite from this child.
				if (!visited[xIndex][yIndex]) {
					[children[xIndex][yIndex] removeSprite:sprite];
					visited[xIndex][yIndex] = YES;
				}
			}
		}
    }
}

- (NSArray *)groupContainingSprite:(Sprite *)sprite
{
    if (isLeaf) return sprites;
	
    // If this is not a leaf node, then we will have to build
    // up the group from the groups returned by the children.
    NSMutableArray *group = [[NSMutableArray alloc] init];
	
    BOOL visited[2][2] = {{NO,NO},{NO,NO}};
    int i, j, x, y, xIndex, yIndex;
    // Loop through the (x,y) coordinates of the four corners
    // of the sprite's bounding rectangle.
    for (i = 0; i < 2; i++) {
		x = sprite->boundingRect.origin.x + i*sprite->boundingRect.size.width;
		xIndex = (x - rect.origin.x) / childWidth;
		if (xIndex < 0 || xIndex > 1) continue;
		
		for (j = 0; j < 2; j++) {
			y = sprite->boundingRect.origin.y + j*sprite->boundingRect.size.height;
			yIndex = (y - rect.origin.y) / childHeight;
			if (yIndex < 0 || yIndex > 1) continue;
			
			// Make sure we haven't already removed the sprite from this child.
			if (!visited[xIndex][yIndex]) {
				visited[xIndex][yIndex] = YES;
				if (children[xIndex][yIndex]) {
					[group addObjectsFromArray:[children[xIndex][yIndex] groupContainingSprite:sprite]];
				}
			}
		}
    }
    
    return [group autorelease];
}


- (NSArray *)groupContainingPoint:(CGPoint)point
{
	NSMutableArray* group = [NSMutableArray array]; 
	if (!CGRectContainsPoint(rect, point))
		return group;
	
    if (isLeaf)
	{
		for (int i =0; i < [sprites count]; ++i)
		{
			Sprite* sprt = (Sprite*)[sprites objectAtIndex:i];
			if (CGRectContainsPoint(sprt.boundingRect, point))
				[group addObject:sprt];
		}
		return group;
	}
	
	 for (int i = 0; i < 2; i++) 
	 {
	     for (int j = 0; j < 2; j++) 
		 {
			 if (children[i][j])
			      [group addObjectsFromArray:[children[i][j] groupContainingPoint:point]];
		 }
	 }
	return group;


}


- (int)numberOfLeafNodes
{
    if (isLeaf) return 1;
	
    int i, j, count = 0;
	
    for (i = 0; i < 2; i++) {
		for (j = 0; j < 2; j++) {
			if (children[i][j]) {
				count += [children[i][j] numberOfLeafNodes];
			}
		}
    }
    
    return count;
}



@end