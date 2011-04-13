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

@implementation MacHPSDRAppDelegate

@synthesize window;

+(void)initialize {
	NSString *defaultsFilename = [[NSBundle mainBundle] pathForResource:@"Defaults" ofType:@"plist"];
	NSDictionary *defaults = [NSDictionary dictionaryWithContentsOfFile:defaultsFilename];
	[[NSUserDefaults standardUserDefaults] registerDefaults:defaults];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {		
	[[NSNotificationCenter defaultCenter] addObserver:self selector: @selector(doNotification:) name: NSUserDefaultsDidChangeNotification object: nil];
	
	[transceiver start];
	[mainReceiver setFrameAutosaveName:@"mainReceiverPosition"];
	[mainReceiver setLevel:NSNormalWindowLevel];
	[subReceiver setFrameAutosaveName:@"subReceiverPosition"];
	[subReceiver setLevel:NSNormalWindowLevel];
	[mainReceiver makeKeyAndOrderFront:nil];
	[window makeMainWindow];
}

-(void)applicationWillTerminate:(NSNotification *)aNotification {
	[transceiver saveParams];
	[transceiver stop];
	[[NSUserDefaults standardUserDefaults] setInteger:[window selectedTab] forKey:@"selectedTab"];
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

@end
