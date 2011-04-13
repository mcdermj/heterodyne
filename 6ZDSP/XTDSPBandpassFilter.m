//
//  XTDSPBandpassFilter.m
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

// $Id: XTDSPBandpassFilter.m 243 2011-04-13 14:40:14Z mcdermj $

#import "XTDSPBandpassFilter.h"

#import "XTBlackmanHarrisWindow.h"
#import "XTRealData.h"

#import <Accelerate/Accelerate.h>

@implementation XTDSPBandpassFilter

@synthesize highCut;
@synthesize lowCut;

-(id)initWithSize: (int) newSize 
	   sampleRate: (float) newSampleRate 
		lowCutoff: (float) lowCutoff 
	andHighCutoff: (float) highCutoff 
{
	self = [super initWithElements: newSize andSampleRate: newSampleRate];
	
	if(self) {
		lowCut = lowCutoff;
		highCut = highCutoff;
		[self calculateCoefficients];
	}
	return self;
}

-(void)setHighCut:(float)highCutoff {
	highCut = highCutoff;
	[self calculateCoefficients];
}

-(void)setLowCut:(float)lowCutoff {
	lowCut = lowCutoff;
	[self calculateCoefficients];
}

-(void)setHighCut: (float)highCutoff andLowCut: (float)lowCutoff {
	[self willChangeValueForKey:@"highCut"];
	[self willChangeValueForKey:@"lowCut"];
	
	highCut = highCutoff;
	lowCut = lowCutoff;
	[self calculateCoefficients];
	
	[self didChangeValueForKey:@"lowCut"];
	[self didChangeValueForKey:@"highCut"];
}

-(void)calculateCoefficients {
	int i;
    float realSum;
    float imagSum;
		
	XTBlackmanHarrisWindow *windowData = 
		[XTBlackmanHarrisWindow blackmanHarrisWindowWithElements:size];
	const float *window = [windowData bytes];
	
	@synchronized(realKernel) {
		[realKernel clearElements];
		[imaginaryKernel clearElements];
		float *realCoefficients = [realKernel elements];
		float *imaginaryCoefficients = [imaginaryKernel elements];
		
		//  Set up the coefficients for a sinc filter.
		float high = highCut / sampleRate;
		float low = lowCut / sampleRate;
		
		float filterCenter = (high - low) / 2.0f;
		float ff = (low + high) * M_PI;
		int midpoint = size >> 1;
		
		for(i = 1; i <= size; ++i) {
			int j = i - 1;
			int k = i - midpoint;
			float temp = 0.0f;
			float phase = k * ff * -1.0f;
			
			if(i != midpoint) {
				temp = (sinf(2.0f * M_PI * k * filterCenter) / (M_PI * k));
			} else {
				temp = 2.0f * filterCenter;
			}
			
			temp *= 2.0f * window[j];
			
			realCoefficients[j] = temp * cosf(phase);
			imaginaryCoefficients[j] = temp * sinf(phase);
            realSum += realCoefficients[j];
            imagSum += imaginaryCoefficients[j];
		}
        
        realSum = realSum == 0.0f ? 1.0f : realSum;
        imagSum = imagSum == 0.0f ? 1.0f : imagSum;
        
         //  Make the filter have unity gain.
        for(i = 0; i < size; ++i) {
            realCoefficients[i] /= realSum;
            imaginaryCoefficients[i] /= imagSum;
        }
        
 		vDSP_fft_zip(fftSetup, &kernel, 1, fftSize, kFFTDirection_Forward);	
 	}
}


@end
