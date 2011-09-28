//
//  XTMainReceiverController.h
//  Heterodyne
//
//  Created by Jeremy McDermond on 7/24/11.
//  Copyright 2011 net.nh6z. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class XTReceiver;
@class SFBInspectorView;
@class XTSMeterView;

@interface XTReceiverController : NSWindowController {
    NSTimer *meterTimer;
}

@property XTReceiver *receiver;
@property IBOutlet SFBInspectorView *inspectorView;
@property IBOutlet NSView *effectsView;
@property IBOutlet NSView *filterView;
@property IBOutlet NSView *frequencyView;
@property IBOutlet NSView *audioView;
@property IBOutlet NSView *meterView;
@property IBOutlet XTSMeterView *meter;

-(id)initWithReceiver:(XTReceiver *) newReceiver;

//-(IBAction)filterDisclosurePressed:(id)sender;
- (IBAction) toggleInspectorPanel:(id)sender;

@end
