//
//  XTMainReceiverController.h
//  Heterodyne
//
//  Created by Jeremy McDermond on 7/24/11.
//  Copyright 2011 net.nh6z. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class TransceiverController;
@class SFBInspectorView;

@interface XTMainReceiverController : NSWindowController

@property TransceiverController *transceiver;
@property IBOutlet SFBInspectorView *inspectorView;
@property IBOutlet NSView *effectsView;
@property IBOutlet NSView *filterView;

-(id)initWithTransceiver:(TransceiverController *) newTransceiver;

-(IBAction)filterDisclosurePressed:(id)sender;
- (IBAction) toggleInspectorPanel:(id)sender;

@end
