//
//  MacHPSDRAppDelegate.h
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

#import <Cocoa/Cocoa.h>

#import "AboutBoxView.h"

@class XTMainWindowController;
@class XTReceiverController;
@class TransceiverController;
@class XTMainWindow;

@interface MacHPSDRAppDelegate : NSObject <NSApplicationDelegate> {
    XTMainWindow *window;
	
	IBOutlet NSPanel *aboutPane;
	
	IBOutlet NSPanel *mainReceiver;
	IBOutlet NSPanel *subReceiver;
    NSWindowController *bandscopeWindow;
    XTMainWindowController *mainWindowController;
    XTReceiverController *mainReceiverController;
    
    TransceiverController *transceiver;
	
	NSArray *drivers;
}

@property (readonly) TransceiverController *transceiver;

-(IBAction)doAbout:(id)sender;
-(IBAction)showMainReceiver:(id)sender;
-(IBAction)showSubReceiver:(id)sender;
-(IBAction)showBandscope:(id)sender;
-(IBAction)swapMainWindow:(id)sender;
-(void)doNotification:(NSNotification *) notification;
-(IBAction)doPreferences:(id)sender;

@end
