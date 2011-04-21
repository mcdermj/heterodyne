//
//  XTDSPComplexOscillator.m
//  Heterodyne
//
//  Created by Jeremy McDermond on 4/20/11.
//  Copyright 2011 net.nh6z. All rights reserved.
//

#import "XTDSPComplexOscillator.h"
#import "XTDSPBlock.h"

@implementation XTDSPComplexOscillator

@synthesize frequency;

- (id)initWithSampleRate:(float)initialSampleRate
{
    self = [super initWithSampleRate:initialSampleRate];
    if (self) {
        // Initialization code here.
    }
    
    return self;
}

-(void)setFrequency:(double)newFrequency {
    frequency = newFrequency;
    phaseAdvance = 2.0 * M_PI * frequency / sampleRate;
}

-(void)performWithComplexSignal:(XTDSPBlock *)signal {
    
    phase = phase > 2.0 * M_PI ? phase - (2.0 * M_PI) : phase;
    phase = phase < -2.0 * M_PI ? phase + (2.0 * M_PI) : phase;
    
    float *realElements = [signal realElements];
    float *imagElements = [signal imaginaryElements];
    
    for(int i = 0; i < [signal blockSize]; ++i) {
        realElements[i] = cos(phase);
        imagElements[i] = sin(phase);
        phase += phaseAdvance;
    }
}

@end
