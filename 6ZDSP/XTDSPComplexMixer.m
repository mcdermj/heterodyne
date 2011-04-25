//
//  XTDSPComplexMixer.m
//  Heterodyne
//
//  Created by Jeremy McDermond on 4/20/11.
//  Copyright 2011 net.nh6z. All rights reserved.
//

#include <Accelerate/Accelerate.h>

#import "XTDSPComplexMixer.h"
#import "XTDSPBlock.h"
#import "XTDSPComplexOscillator.h"


@implementation XTDSPComplexMixer

-(id)initWithSampleRate:(float)initialSampleRate {
    self = [super initWithSampleRate:initialSampleRate];
    if(self) {
        oscillator = [[XTDSPComplexOscillator alloc] initWithSampleRate:initialSampleRate];
        oscillatorBlock = [XTDSPBlock dspBlockWithBlockSize:1024];
    }
    return self;
}

-(void)setLoFrequency:(float)frequency {
    [oscillator setFrequency:frequency];
}

-(float)loFrequency {
    return [oscillator frequency];
}

-(void)performWithComplexSignal:(XTDSPBlock *)signal {
    if([oscillatorBlock blockSize] != [signal blockSize]) 
        oscillatorBlock = [XTDSPBlock dspBlockWithBlockSize:[signal blockSize]];
    
    [oscillatorBlock clearBlock];
    [oscillator performWithComplexSignal:oscillatorBlock];
    
    vDSP_zvmul([signal signal], 1, [oscillatorBlock signal], 1, [signal signal], 1, [signal blockSize], 1);
}

@end
