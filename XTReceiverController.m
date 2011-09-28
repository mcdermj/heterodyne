//
//  XTMainReceiverController.m
//  Heterodyne
//
//  Created by Jeremy McDermond on 7/24/11.
//  Copyright 2011 net.nh6z. All rights reserved.
//

#import "XTReceiverController.h"
#import "XTReceiver.h"
#import "XTSMeterView.h"

#import "SFBInspectorView.h"


@implementation XTReceiverController

@synthesize receiver;
@synthesize filterView;
@synthesize effectsView;
@synthesize inspectorView;
@synthesize frequencyView;
@synthesize audioView;
@synthesize meterView;
@synthesize meter;

-(id)init {
    self = [super initWithWindowNibName:@"ReceiverInspector"];
    
    return self;
}

-(id)initWithReceiver:(XTReceiver *) newReceiver {
    self = [super initWithWindowNibName:@"ReceiverInspector"];
    if (self) {
        receiver = newReceiver;
        
        meterTimer = [NSTimer scheduledTimerWithTimeInterval:0.06 
                                                      target:self 
                                                    selector:@selector(updateMeter) 
                                                    userInfo:nil 
                                                     repeats:YES];
    }
    
    return self;
}

-(NSString *) windowFrameAutosaveName {
    if(receiver == [XTReceiver mainReceiver]) 
        return @"Main Receiver";
    else if(receiver == [XTReceiver subReceiver])
        return @"Sub Receiver";
    else
        return nil;
}

- (void)windowDidLoad
{
    [[self window] setMovableByWindowBackground:YES];
    
    [inspectorView addInspectorPane:meterView title:@"S-Meter"];
    [inspectorView addInspectorPane:frequencyView title:NSLocalizedString(@"Frequency/Mode", @"Frequency/Mode Parameters")];
    [inspectorView addInspectorPane:filterView title:NSLocalizedString(@"Filter", @"The filter parameters")];
    [inspectorView addInspectorPane:effectsView title:@"RF Processing"];
    [inspectorView addInspectorPane:audioView title:@"Audio"];
    
    
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

-(void)updateMeter {
    [meter setSignal:[receiver signalLevel]];
}

@end
