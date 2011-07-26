//
//  XTMainWindowController.m
//  Heterodyne
//
//  Created by Jeremy McDermond on 7/23/11.
//  Copyright 2011 net.nh6z. All rights reserved.
//

#import "XTMainWindowController.h"

@implementation XTMainWindowController

@synthesize transceiver;
@synthesize waterfall;
@synthesize panadapter;

-(id)initWithTransceiver:(TransceiverController *) newTransceiver {
    self = [super initWithWindowNibName:@"Main Window"];
    if (self) {
        transceiver = newTransceiver;
    }
    
    return self;
}

- (id)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    if (self) {
        // Initialization code here.
    }
    
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
}

@end
