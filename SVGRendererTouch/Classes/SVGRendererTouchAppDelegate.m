//
//  SVGRendererTouchAppDelegate.m
//  SVGRendererTouch
//
//  Created by Aaron Boxer on 10-10-15.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "SVGRendererTouchAppDelegate.h"
#import "SVGRenderViewTouch.h"

@interface SVGRendererTouchAppDelegate (private)

    -(void) parse;
    -(void) render;
@end



@implementation SVGRendererTouchAppDelegate

@synthesize window, svgView;



#pragma mark -
#pragma mark Application lifecycle

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {    
    
    // Override point for customization after application launch.
    
    [window makeKeyAndVisible];	
	
	CGRect bounds = [[UIScreen mainScreen] bounds];
	
	// shift below "carrier" window at top of screen
	bounds.origin.y = 20;
	bounds.size.height -= 20;
	UIView* topView = [[UIView alloc] initWithFrame:bounds];
	[window addSubview:topView];
	[topView release];

	//set origin to (0,0)
	bounds.origin.y = 0;
	SVGRenderViewTouch* view = [[SVGRenderViewTouch alloc] initWithFrame:bounds];
    self.svgView = view;
    [view release];
    
	[svgView setDelegate:self];    
    [topView addSubview:svgView];    
    [svgView release];
    
    queue = [[NSOperationQueue alloc] init];
    
    NSInvocationOperation *updateOperation = [[NSInvocationOperation alloc] initWithTarget:self selector:@selector(parse) object:nil];
    [queue addOperation:updateOperation];
    [updateOperation release];
    
    return YES;
}


-(void) parse
{
  	NSString *path = [[NSBundle mainBundle] pathForResource:@"map" ofType:@"svg"];
	[self.svgView open:path];     
    [self performSelectorOnMainThread:@selector(render)
                                           withObject:nil
                                        waitUntilDone:NO];
 
    
}

-(void) render
{
    [self.svgView render];      
}


- (void)applicationWillResignActive:(UIApplication *)application {
    /*
     Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
     Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
     */
}


- (void)applicationDidEnterBackground:(UIApplication *)application {
    /*
     Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
     If your application supports background execution, called instead of applicationWillTerminate: when the user quits.
     */
}


- (void)applicationWillEnterForeground:(UIApplication *)application {
    /*
     Called as part of  transition from the background to the inactive state: here you can undo many of the changes made on entering the background.
     */
}


- (void)applicationDidBecomeActive:(UIApplication *)application {
    /*
     Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
     */
}


- (void)applicationWillTerminate:(UIApplication *)application {
    /*
     Called when the application is about to terminate.
     See also applicationDidEnterBackground:.
     */
}


#pragma mark -
#pragma mark Memory management

- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application {
    /*
     Free up as much memory as possible by purging cached data objects that can be recreated (or reloaded from disk) later.
     */
}


- (void)dealloc {
    [window release];
    [queue release];
    queue = nil;
    [super dealloc];
}

#pragma mark -
#pragma mark SVGRenderViewTouchDelegate methods

- (void) doubleTap:(NSString*)location
{
	
}
- (void) singleTap:(NSString*)location
{
	
	
}

@end
