//
//  XTDSPAutomaticGainControl.h
//  MacHPSDR
//
//  Copyright (c) 2010 - Jeremy C. McDermond (NH6Z)

// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 2
// of the License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.

// $Id: XTDSPAutomaticGainControl.h 243 2011-04-13 14:40:14Z mcdermj $

#import <Cocoa/Cocoa.h>

#import "XTDSPModule.h"

#define dbToValue(x) sqrt(2.0f) * powf(10.0f, (x / 20.0f))
#define valueToDb(x) 20.0f * log10f(x / sqrt(2.0))

@class XTRealData;
@class XTSplitComplexData;

@interface XTDSPAGCDetector : NSObject {
    float attack;
    float decay;
    float gain;
    float hangtime;
    float hangthresh;
    float topGain;
    float bottomGain;
    float limitGain;
    
    float *realElements;
    float *imaginaryElements;
    
    int index;
    int hang;
    int mask;
}

@property float attack;
@property float decay;
@property float gain;
@property float hangtime;
@property float topGain;
@property float bottomGain;
@property float limitGain;
@property int index;
@property int hang;
@property float hangthresh;

-(float)calculateGain;
-(id)initWithBuffer:(XTSplitComplexData *)buffer;

@end 

@interface XTDSPAutomaticGainControl : XTDSPModule {
    XTSplitComplexData *buffer;
    float *realElements;
    float *imaginaryElements;
    
    XTDSPAGCDetector *slowDetector;
    XTDSPAGCDetector *fastDetector;
    
	float attack;
	float decay;
	float slope;
	float maxGain;
	float minGain;
	float currentGain;
    float limit;
	
	float hangTime;
	
	float hangThreshold;
	
	int mask;
    
    int hang;
    
	int index;
    
	int insertionPoint;		
	NSRange copyRange;
	NSRange bufferRange;
    
    IBOutlet NSImageView *thresholdLED;
    NSImage *darkLED;
    NSImage *redLED;
    BOOL active;
    
    float threshold;
}

@property float attack;
@property float decay;
@property float slope;
@property float hangTime;
@property float maxGain;
@property float minGain;
@property float currentGain;
@property float limit;
@property float threshold;

@end
