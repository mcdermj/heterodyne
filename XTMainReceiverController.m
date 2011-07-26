//
//  XTMainReceiverController.m
//  Heterodyne
//
//  Created by Jeremy McDermond on 7/24/11.
//  Copyright 2011 net.nh6z. All rights reserved.
//

#import "XTMainReceiverController.h"
#import "TransceiverController.h"

#import "SFBInspectorView.h"


@implementation XTMainReceiverController

@synthesize transceiver;
@synthesize filterView;
@synthesize effectsView;
@synthesize inspectorView;

-(id)init {
    self = [super initWithWindowNibName:@"ReceiverInspector"];
    
    return self;
}

-(id)initWithTransceiver:(TransceiverController *) newTransceiver {
    self = [super initWithWindowNibName:@"ReceiverInspector"];
    if (self) {
        transceiver = newTransceiver;
    }
    
    return self;
}

-(NSString *) windowFrameAutosaveName {
    return @"Main Receiver";
}

- (void)windowDidLoad
{
    [[self window] setMovableByWindowBackground:YES];
    
    [inspectorView addInspectorPane:filterView title:NSLocalizedString(@"Filter", @"The filter parameters")];
    [inspectorView addInspectorPane:effectsView title:@"RF Processing"]; 
    
    [super windowDidLoad];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
}

- (IBAction) toggleInspectorPanel:(id)sender
{
    NSWindow *window = self.window;
	
	if(window.isVisible)
		[window orderOut:sender];
	else
		[window orderFront:sender];
}

@end
