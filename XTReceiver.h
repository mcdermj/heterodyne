//
//  XTReceiver.h
//  Heterodyne
//
//  Created by Jeremy McDermond on 9/28/11.
//  Copyright 2011 net.nh6z. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface XTReceiver : NSObject {
    int receiverNumber;
    float frequency;
}

+(XTReceiver *)mainReceiver;
+(XTReceiver *)subReceiver;

@property (readonly) int receiverNumber;
@property float pan;
@property float gain;
@property BOOL noiseReduction;
@property BOOL autoNotchFilter;
@property BOOL noiseBlanker;
@property BOOL binaural;
@property (readonly) float signalLevel;
@property float frequency;
@property int mode;
@property float filterLow;
@property float filterHigh;
@property float filterCenter;
@property float filterWidth;

-(void)setFilterWidth:(float)filterWidth andCenter:(float)filterCenter;
-(void)setFilterLow:(float)filterLow andHigh:(float)filterHigh;

@end
