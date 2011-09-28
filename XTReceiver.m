//
//  XTReceiver.m
//  Heterodyne
//
//  Created by Jeremy McDermond on 9/28/11.
//  Copyright 2011 net.nh6z. All rights reserved.
//

#import "XTReceiver.h"
#import "TransceiverController.h"
#import "MacHPSDRAppDelegate.h"
#import "XTHeterodyneHardwareDriver.h"

#include "dttsp.h"

@implementation XTReceiver

@synthesize receiverNumber;
@synthesize pan;
@synthesize gain;
@synthesize noiseReduction;
@synthesize autoNotchFilter;
@synthesize noiseBlanker;
@synthesize binaural;

static XTReceiver* _mainReceiver;
static XTReceiver* _subReceiver;

- (id)initWithReceiverNumber:(int)_number {
    self = [super init];
    if (self) {
        receiverNumber = _number;      
        frequency = 0.0f;
    }
    
    return self;
}

+(XTReceiver *)mainReceiver {
    @synchronized([XTReceiver class]) {
        if(!_mainReceiver) 
            [[self alloc] init];
        
        return _mainReceiver;
    }
    
    return nil;
}

+(XTReceiver *)subReceiver {
    @synchronized([XTReceiver class]) {
        if(!_subReceiver) 
            [[self alloc] init];
        
        return _subReceiver;
    }
    
    return nil;
}

+(id)alloc {
    @synchronized([XTReceiver class]) {
        NSAssert(_mainReceiver == nil, @"Attempted to allocate mainReciever twice");
        _mainReceiver = [super alloc];
        [_mainReceiver initWithReceiverNumber:0];
        
        NSAssert(_subReceiver == nil, @"Attempted to allocate subReciever twice");
        _subReceiver = [super alloc];
        [_subReceiver initWithReceiverNumber:1];
    }
    
    return nil;
}

-(void)setPan:(float)newPan {
    pan = newPan;
    SetRXPan(0, receiverNumber, pan);
}

-(void)setGain:(float)newGain {
    gain = newGain;
    
    SetRXOutputGain(0, receiverNumber, gain);
}

-(void)setNoiseReduction:(BOOL)isNoiseReduction {
    noiseReduction = isNoiseReduction;
    
    if(noiseReduction == YES)
        SetNR(0, receiverNumber, 1);
    else
        SetNR(0, receiverNumber, 0);
}

-(void)setAutoNotchFilter:(BOOL)isAutoNotchFilter {
    autoNotchFilter = isAutoNotchFilter;
    
    if(autoNotchFilter == YES) 
        SetANF(0, receiverNumber, 1);
    else
        SetANF(0, receiverNumber, 0);
}

-(void)setNoiseBlanker:(BOOL)isNoiseBlanker {
    noiseBlanker = isNoiseBlanker;
    
    if(noiseBlanker == YES)
        SetNB(0, receiverNumber, 1);
    else
        SetNB(0, receiverNumber, 0);
}

-(void)setBinaural:(BOOL)isBinaural {
    binaural = isBinaural;
    
    if(binaural == YES)
        SetBIN(0, receiverNumber, 1);
    else
        SetBIN(0, receiverNumber, 0);
}

-(float)signalLevel {
    return CalculateRXMeter(0, receiverNumber, 0);
}

-(float)frequency {
    id<XTHeterodyneHardwareDriver> interface = (id<XTHeterodyneHardwareDriver>) [[((MacHPSDRAppDelegate *) [NSApp delegate]) transceiver] interface];
    if(interface == nil) {
        NSLog(@"[%@ %s] No interface yet present.\n", [self class], (char *) _cmd);
        return -1.0;
    }
    float passbandCenter = (float) [interface getFrequency:0];
    
    return passbandCenter + frequency;
}

-(void)setFrequency:(float)newFrequency {
    if(receiverNumber == 0) {
        id<XTHeterodyneHardwareDriver> interface = (id<XTHeterodyneHardwareDriver>) [[((MacHPSDRAppDelegate *) [NSApp delegate]) transceiver] interface];
        [interface setFrequency:(int)newFrequency forReceiver:0];
        frequency = 0.0f;
    } else {
        
    }
}

@end
