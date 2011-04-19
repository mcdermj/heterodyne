//
//  XTReceiver.m
//  Heterodyne
//
//  Created by Jeremy McDermond on 4/19/11.
//  Copyright 2011 net.nh6z. All rights reserved.
//

#import "XTReceiver.h"

#import "XTWorkerThread.h"
#import "XTDSPBandpassFilter.h"
#import "XTDSPModule.h"
#import "XTHeterodyneHardwareDriver.h"
#import "XTDSPAutomaticGainControl.h"

@implementation XTReceiver

@synthesize sampleRate;

- (id)initWithSampleRate: (float)initialSampleRate
{
    self = [super init];
    if (self) {
        sampleRate = initialSampleRate;
        
        workerThread = [[XTWorkerThread alloc] initWithRealtime:YES];
        [workerThread start];
        
        dspModules = [NSMutableArray arrayWithCapacity:2];
        
        [dspModules addObject:[[XTDSPBandpassFilter alloc] initWithSize:1024
                                                             sampleRate:sampleRate
                                                              lowCutoff:0.0f
                                                          andHighCutoff:2700.0f]];
        
        [dspModules addObject:[[XTDSPAutomaticGainControl alloc] initWithSampleRate:sampleRate]];
    }
    return self;
}

-(XTDSPBandpassFilter *)filter {
    for(XTDSPModule *module in dspModules)
        if([module class] == [XTDSPBandpassFilter class])
            return (XTDSPBandpassFilter *) module;
    
    return nil;
}

-(void)setHighCut: (float)highCutoff {
	[[self filter] setHighCut:highCutoff];
}

-(float)highCut {
    return [[self filter] highCut];
}

-(void)setLowCut: (float)lowCutoff {
	[[self filter] setLowCut:lowCutoff];
}

-(float)lowCut {
    return [[self filter] lowCut];
}

-(void)setSampleRate:(float)newSampleRate {
	sampleRate = newSampleRate;
    
	for(XTDSPModule *module in dspModules) 
		[module setSampleRate:newSampleRate];
	
}

-(void)processComplexSamples: (XTDSPBlock *)complexData withCompletionSelector:(SEL) completion onObject:(id)callbackObject {
    
	for(XTDSPModule *module in dspModules)
		[module performSelector: @selector(performWithComplexSignal:) 
					   onThread: workerThread 
					 withObject: complexData
				  waitUntilDone: NO];
	
    [callbackObject performSelector:completion
                           onThread:workerThread
                         withObject:nil
                      waitUntilDone:NO];
}

@end
