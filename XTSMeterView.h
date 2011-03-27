//
//  XTSMeter.h
//  XTSMeterTest
//
//  Created by Jeremy McDermond on 3/16/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface XTSMeterView : NSView {
@private
    
    float needlePos;
    
    float sweep;
    
    float signal;
    
}

@property float needlePos;
@property float signal;

@end
