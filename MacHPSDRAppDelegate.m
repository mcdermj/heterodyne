//
//  MacHPSDRAppDelegate.m
//  MacHPSDR
//
//  Copyright (c) 2010 - Jeremy C. McDermond (NH6Z)

// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 2
// of the License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.

// $Id$

#import "MacHPSDRAppDelegate.h"
#import "XTHeterodyneHardwareDriver.h"
#import "XTMainWindowController.h"
#import "XTReceiverController.h"
#import "XTWaterfallView.h"
#import "XTPanAdapterView.h"
#import "XTReceiver.h"

#import "dttsp.h"

@implementation MacHPSDRAppDelegate

@synthesize transceiver;

+(void)initialize {
	NSString *defaultsFilename = [[NSBundle mainBundle] pathForResource:@"Defaults" ofType:@"plist"];
	NSDictionary *defaults = [NSDictionary dictionaryWithContentsOfFile:defaultsFilename];
	[[NSUserDefaults standardUserDefaults] registerDefaults:defaults];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {		
	[[NSNotificationCenter defaultCenter] addObserver:self selector: @selector(doNotification:) name: NSUserDefaultsDidChangeNotification object: nil];
    
    transceiver = [[TransceiverController alloc] init];
    
    //  Load up the main window NIB
    mainWindowController = [[XTMainWindowController alloc] initWithTransceiver:transceiver];
    [[mainWindowController window] makeMainWindow];
	[mainWindowController showWindow:nil];
    
    mainReceiverController = [[XTReceiverController alloc] initWithReceiver:[XTReceiver mainReceiver]];
    [mainReceiverController showWindow:self];
    
	[transceiver start];
	[mainReceiver setFrameAutosaveName:@"mainReceiverPosition"];
	[mainReceiver setLevel:NSNormalWindowLevel];
	[subReceiver setFrameAutosaveName:@"subReceiverPosition"];
	[subReceiver setLevel:NSNormalWindowLevel];
	[mainReceiver makeKeyAndOrderFront:nil];
    
}

-(void)applicationWillTerminate:(NSNotification *)aNotification {
	[transceiver saveParams];
	[transceiver stop];
}


-(IBAction)doAbout:(id) sender {
	[aboutPane makeKeyAndOrderFront: nil];
}

-(void)doNotification: (NSNotification *) notification {
	NSString *notificationName = [notification name];
	
	if( notificationName == NSUserDefaultsDidChangeNotification ) {
		[transceiver refreshParams];
	}
}

-(IBAction)showMainReceiver:(id) sender {
	[mainReceiver makeKeyAndOrderFront:nil];
}

-(IBAction)showSubReceiver:(id) sender {
	[subReceiver makeKeyAndOrderFront:nil];
}

-(IBAction)showBandscope:(id)sender {
    bandscopeWindow = [[NSWindowController alloc] initWithWindowNibName:@"Bandscope Window"];

    [bandscopeWindow showWindow:nil];
}

-(IBAction)swapMainWindow:(id)sender {
    XTWaterfallView *waterfall = [mainWindowController waterfall];
    XTPanAdapterView *panadapter = [mainWindowController panadapter];
    NSView *scrollView = [waterfall superview];
    
    [waterfall removeFromSuperview];
    [panadapter removeFromSuperview];
    
    if([sender state] == NSOnState) {
        //  Was swapped, go to regular -- panadapter on top
        [scrollView addSubview:panadapter];
        [scrollView addSubview:waterfall];
        [waterfall setFlowsUp:NO];
        [sender setState:NSOffState];
        [sender setTitle:@"Waterfall On Top"];
    } else {
        [scrollView addSubview:waterfall];
        [scrollView addSubview:panadapter];
        [waterfall setFlowsUp:YES];
        [sender setState:NSOnState];
        [sender setTitle:@"Waterfall On Bottom"];
    }
}

-(IBAction)doPreferences:(id)sender {
    //  XXX This is *WAY* ugly.  Should be done some other way.
    [transceiver doPreferences:sender];
}

@end
