//
//  XTMainWindowController.h
//  Heterodyne
//
//  Created by Jeremy McDermond on 7/23/11.
//  Copyright 2011 net.nh6z. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class TransceiverController;
@class XTWaterfallView;
@class XTPanAdapterView;

@interface XTMainWindowController : NSWindowController

@property TransceiverController *transceiver;
@property IBOutlet XTWaterfallView *waterfall;
@property IBOutlet XTPanAdapterView *panadapter;

-(id)initWithTransceiver:(TransceiverController *) newTransceiver;

@end

