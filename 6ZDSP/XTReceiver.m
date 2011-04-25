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
#import "XTDSPDemodulator.h"
#import "XTDSPComplexMixer.h"
#import "XTDSPBlock.h"

@implementation XTReceiver

@synthesize sampleRate;
@synthesize results;

- (id)initWithSampleRate: (float)initialSampleRate
{
    self = [super init];
    if (self) {
        sampleRate = initialSampleRate;
        
        workerThread = [[XTWorkerThread alloc] initWithRealtime:YES];
        [workerThread start];
        
        results = [XTDSPBlock dspBlockWithBlockSize:1024];
        
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

-(XTDSPDemodulator *)demodulator {
    for(XTDSPModule *module in dspModules)
        if([module class] == [XTDSPDemodulator class])
            return (XTDSPDemodulator *) module;
    
    return nil;
}

-(XTDSPComplexMixer *)mixer {
    for(XTDSPModule *module in dspModules)
        if([module class] == [XTDSPComplexMixer class])
            return (XTDSPComplexMixer *) module;
    
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

-(void)setFrequency:(float)frequency {
    if(frequency == 0.0) {
        [dspModules removeObject:[self mixer]];
        return;
    }
    
    if([self mixer] == nil) {
        [dspModules insertObject:[[XTDSPComplexMixer alloc] initWithSampleRate:sampleRate] atIndex:0];
    }
    
    [[self mixer] setLoFrequency:frequency];
}

-(float)frequency {
    if([self mixer] == nil) return 0.0;
    
    return [[self mixer] loFrequency];
}

-(void)setSampleRate:(float)newSampleRate {
	sampleRate = newSampleRate;
    
	for(XTDSPModule *module in dspModules) 
		[module setSampleRate:newSampleRate];
}

-(void)processComplexSamples: (XTDSPBlock *)complexData withCompletionSelector:(SEL) completion onObject:(id)callbackObject {
    if([results blockSize] != [complexData blockSize])
        results = [XTDSPBlock dspBlockWithBlockSize:[complexData blockSize]];
    
    [complexData copyTo:results];
    
	for(XTDSPModule *module in dspModules)
		[module performSelector: @selector(performWithComplexSignal:) 
					   onThread: workerThread 
					 withObject: results
				  waitUntilDone: NO];
	
    [callbackObject performSelector:completion
                           onThread:workerThread
                         withObject:nil
                      waitUntilDone:NO];
}

@end
