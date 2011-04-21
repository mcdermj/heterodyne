//
//  XTDSPComplexMixer.h
//  Heterodyne
//
//  Created by Jeremy McDermond on 4/20/11.
//  Copyright 2011 net.nh6z. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "XTDSPModule.h"

@class XTDSPBlock;
@class XTDSPComplexOscillator;

@interface XTDSPComplexMixer : XTDSPModule {
@private
    XTDSPBlock *oscillatorBlock;
    XTDSPComplexOscillator *oscillator;
}

@property float loFrequency;

@end
