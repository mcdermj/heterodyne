//
//  XTDSPHighpassFilter.m
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

// $Id: XTDSPHighpassFilter.m 141 2010-03-18 21:19:57Z mcdermj $

#import "XTDSPHighpassFilter.h"

#import "XTBlackmanHarrisWindow.h"
#import "XTRealData.h"


@implementation XTDSPHighpassFilter
-(id)initWithSize: (int) newSize sampleRate: (float)newSampleRate andCutoff: (float) cutoff {
	
	// size must be odd
	if(newSize %2 == 0) {
		--newSize;
	}
	
	size = newSize;
	
	self = [super initWithElements: size andSampleRate: newSampleRate];
	if(self) {
		int i;
		// float runningSum = 0.0f;
		
		XTBlackmanHarrisWindow *windowData = [XTBlackmanHarrisWindow blackmanHarrisWindowWithElements:size];
		const float *window = [windowData bytes];
		float *realCoefficients = [realKernel elements];
		float *imaginaryCoefficients = [imaginaryKernel elements];
		
		int midPoint = (size - 1) / 2;
		cutoff /= sampleRate;
		
		for(i = 0; i < size; ++i) {
			float distance = (float) (i - midPoint);
			if(distance == 0) {
				realCoefficients[i] = 2.0f * M_PI * cutoff;
				imaginaryCoefficients[i] = 2.0f * M_PI * cutoff;
			} else {
				realCoefficients[i] = sinf(2.0f * M_PI * distance * cutoff ) /
				(M_PI * distance);
				imaginaryCoefficients[i] = cosf(2.0f * M_PI * distance * cutoff) / 
				(M_PI * distance);
			} 
			realCoefficients[i] *= window[i];
			imaginaryCoefficients[i] *= window[i];
			//runningSum += realCoefficients[i];
		}
		
		//  To create a highpass filter, negate the elements and add one to the
		//  center
		//vDSP_vneg(coefficients, 1, coefficients, 1, size);
		//coefficients[midPoint] += 1;
		
		//vDSP_fft_zip(fftSetup, [coefficientsData DSPSplitComplex], 1, fftSize, kFFTDirection_Forward);
	}
	return self;
}

@end
