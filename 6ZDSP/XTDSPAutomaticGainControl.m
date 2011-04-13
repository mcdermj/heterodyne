//
//  XTDSPAutomaticGainControl.m
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

// $Id: XTDSPAutomaticGainControl.m 243 2011-04-13 14:40:14Z mcdermj $

#import "XTDSPAutomaticGainControl.h"

#import "XTRealData.h"
#import "XTDSPBlock.h"
#import "XTSplitComplexData.h"

@implementation XTDSPAGCDetector

@synthesize attack;
@synthesize decay;
@synthesize gain;
@synthesize topGain;
@synthesize bottomGain;
@synthesize limitGain;
@synthesize index;
@synthesize hang;
@synthesize hangthresh;
@synthesize hangtime;

-(id)initWithBuffer:(XTSplitComplexData *)buffer {
    self = [super init];
    
    if(self) {
        realElements = [buffer realElements];
        imaginaryElements = [buffer imaginaryElements];
        mask = [buffer elementLength] - 1;
    }
    
    return self;
}

-(float)calculateGain {
    float tmp = hypotf(realElements[index], imaginaryElements[index]);
    
    tmp = tmp > 0.00000005f ? limitGain / tmp : gain;
    
    if(tmp < hangthresh)
        hang = hangtime;
    if(tmp >= gain) {
        if(hang++ > hangtime) 
            gain = (1.0f - decay) * gain + decay * fminf(topGain, tmp);
    } else {
        hang = 0;
        gain = (1.0f - attack) * gain + attack * fmaxf(tmp, bottomGain);
    }
    
    gain = fmaxf(fminf(gain, topGain), bottomGain);
    index = ++index > mask ? 0 : index;
    return gain;
}

-(void)setHangthresh:(float)newHangthresh {
    if(newHangthresh > 0)
        hangthresh = topGain * newHangthresh + bottomGain * (1.0f - newHangthresh);
    else
        hangthresh = 0;
}

@end

@implementation XTDSPAutomaticGainControl

@synthesize attack;
@synthesize decay;
@synthesize slope;
@synthesize maxGain;
@synthesize minGain;
@synthesize currentGain;
@synthesize limit;
@synthesize hangTime;
@synthesize threshold;

-(void)setHangThreshold:(float)newHangThresh {
    hangThreshold = newHangThresh;
    
    [fastDetector setHangthresh:newHangThresh];
    [slowDetector setHangthresh:newHangThresh];
}

-(void)setLimit:(float)newLimit {
    limit = newLimit;
    [slowDetector setLimitGain:limit];
    [fastDetector setLimitGain:limit];
}

-(void)setLED:(NSNumber *)status {
    if([status boolValue]) {
        [thresholdLED setImage:redLED];
    } else {
        [thresholdLED setImage:darkLED];
    }
}

-(id)initWithSampleRate: (float) newSampleRate {
	self = [super initWithSampleRate:192000.0f];
	if(self) {
		
		// Initialize values -- this should be done elsewhere eventually
        // Sample rate too
		slope = 1.0f;
		currentGain = 1.0f;
		int size = 1024;
         
        buffer = [XTSplitComplexData splitComplexDataWithElements:size * 4];
        realElements = [buffer realElements];
        imaginaryElements = [buffer imaginaryElements];

        slowDetector = [[XTDSPAGCDetector alloc] initWithBuffer:buffer];
        fastDetector = [[XTDSPAGCDetector alloc] initWithBuffer:buffer];
        
        //  These are defaults.  Should be changed.
        [self setAttack:2.0f];
        [self setDecay:250.0f];
        [self setHangTime:250.0f];
        [self setMaxGain:31622.8f];
		[self setMinGain:0.00001f];
        [self setLimit:1.0f];
        
        [fastDetector setAttack:expf(-1000.0f / (0.2f * sampleRate))];
        [fastDetector setDecay:expf(-1000.0f / (3.0 * sampleRate))];
        [fastDetector setIndex:mask - (int)(0.002f * sampleRate)];
        [fastDetector setHang:0];
        [fastDetector setHangtime:0.1f * hangTime];
        
        [self setHangThreshold:minGain];
        [fastDetector setGain:currentGain];
        [slowDetector setGain:currentGain];
 		
		mask = [buffer elementLength] - 1;
		index = (int) mask - (sampleRate * attack * 0.003f);
         
		bufferRange = NSMakeRange(0, mask);		
		copyRange = NSMakeRange(0, mask);
        
        // XXX For Testing Only
        if(thresholdLED == nil) {
            if(![NSBundle loadNibNamed:@"AGCPanel" owner:self] ) {
                NSLog(@"[%@ %s] Could not load bundle.\n", [self class], (char *) _cmd);
                
            }
        }
        
        darkLED = [[NSImage alloc] initByReferencingFile:[[NSBundle mainBundle] pathForImageResource:@"Dark LED"]];
        redLED = [[NSImage alloc] initByReferencingFile:[[NSBundle mainBundle] pathForImageResource:@"Red LED"]];
        
        [thresholdLED setImage:darkLED];
        
        threshold = -25.0f;
        
	}
	return self;
}

-(void)setMaxGain:(float) newMaxGain {
    maxGain = newMaxGain;
    [fastDetector setTopGain:maxGain];
    [slowDetector setTopGain:maxGain];
    
    [self setHangThreshold:maxGain * hangThreshold + minGain * (1.0f - hangThreshold)];
}

-(void)setMinGain:(float) newMinGain {
	minGain = newMinGain;
    
    [fastDetector setBottomGain:minGain];
    [slowDetector setBottomGain:minGain];
    
    [self setHangThreshold:maxGain * hangThreshold + minGain * (1.0f - hangThreshold)];
}

-(void)setAttack:(float)newAttack {
    attack = newAttack;
    [slowDetector setAttack:expf(-1000.0f / (newAttack * sampleRate))];
}

-(void)setDecay:(float) newDecay {
    decay = newDecay;
    [slowDetector setDecay:expf(-1000.0f / (newDecay * sampleRate))];
}

-(void)setHangTime:(float)newHangTime {
    hangTime = newHangTime;
    [slowDetector setHangtime:(hangTime * 0.001f) * sampleRate];
}

-(void)performWithComplexSignal: (XTDSPBlock *)signal {
    DSPSplitComplex copyBuffer;
    
    copyBuffer.realp = &(realElements[insertionPoint]);
    copyBuffer.imagp = &(imaginaryElements[insertionPoint]);
    
    if(insertionPoint + [signal blockSize] <= [buffer elementLength]) {
        vDSP_zvmov([signal signal] , 1, &copyBuffer, 1, [signal blockSize]);
        insertionPoint += [signal blockSize];
        insertionPoint = insertionPoint > mask ? 0 : insertionPoint;
    } else {
        int firstLength = [buffer elementLength] - insertionPoint;
        int secondLength = [signal blockSize] - firstLength;
        
        vDSP_zvmov([signal signal] , 1, &copyBuffer, 1, firstLength);
        
        copyBuffer.realp = &([signal realElements][firstLength]);
        copyBuffer.imagp = &([signal imaginaryElements][firstLength]);
        vDSP_zvmov(&copyBuffer , 1, [buffer DSPSplitComplex], 1, secondLength);
        insertionPoint = secondLength;
    }
        

    float rise = 10.0f;
    
    float knee = dbToValue(threshold);
    slope = rise / -threshold;
    float intercept = threshold + rise;
    intercept = dbToValue(intercept);
    float exponent = log10f(intercept / knee) / log10f(1.0f / knee);
    float mag;
    
    hangTime = 300.0f;
    int hangSamples = (int)((hangTime / 1000.0f) * sampleRate);
    
    float decayTime = 1000.0f;
    int decaySamples = (int)((decayTime / 1000.0f) * sampleRate);
    float decayFactor = 1.0f - expf(-5.0f / (float) decaySamples);

    for(int i = 0; i < [signal blockSize]; ++i) {
/*        float scaleFactor = fminf([fastDetector calculateGain], fminf(slope * [slowDetector calculateGain], maxGain));
        [signal realElements][i] = realElements[index] * scaleFactor;
        [signal imaginaryElements][i] = imaginaryElements[index] * scaleFactor; */
        
        float gain;
        
        mag = hypotf([signal realElements][i], [signal imaginaryElements][i]);
        
        if(mag > knee) {
            gain = (powf(mag / knee, exponent) * knee) / mag;
            if(!active) {
                [self performSelectorOnMainThread:@selector(setLED:) withObject:[NSNumber numberWithBool:YES] waitUntilDone:NO];
                active = YES;
            }
            // XXX Send notification for indicator here
            // NSLog(@"AGC Active, applying gain of %f for level %f(%f), values %f %f\n", gain, valueToDb(mag), mag, [signal realElements][i], [signal imaginaryElements][i]);
        } else {
            if(active) {
                [self performSelectorOnMainThread:@selector(setLED:) withObject:[NSNumber numberWithBool:NO] waitUntilDone:NO];
                active = NO;
            }
            
            gain = 1.0f;
        }
        
        if(gain < currentGain) {
            // Attack
            currentGain = gain;
            hang = 0;
        } else {
            // Decay
            if(hang > hangSamples) {
                currentGain = currentGain + ((gain - currentGain) * decayFactor);
                //currentGain = gain;
            } else {
                ++hang;
            }
        }
        
        [signal realElements][i] = realElements[index] * currentGain;
        [signal imaginaryElements][i] = imaginaryElements[index] * currentGain;
        
        index = ++index > mask ? 0 : index;
    }
    
    // NSLog(@"AGC Gain is %f\n", currentGain);
}

@end
