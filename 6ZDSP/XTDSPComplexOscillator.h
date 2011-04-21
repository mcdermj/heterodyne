//
//  XTDSPComplexOscillator.h
//  Heterodyne
//
//  Created by Jeremy McDermond on 4/20/11.
//  Copyright 2011 net.nh6z. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "XTDSPModule.h"

@interface XTDSPComplexOscillator : XTDSPModule {
@private
    double frequency;
    double phase;
    double phaseAdvance;
}

@property double frequency;

@end
