//
//  XTDSPFilter.m
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

// $Id: XTDSPFilter.m 243 2011-04-13 14:40:14Z mcdermj $

#import "XTDSPFilter.h"

#import "XTRealData.h"
#import "XTDSPBlock.h"

#import <Accelerate/Accelerate.h>


@implementation XTDSPFilter

@synthesize kernel;

-(id)initWithElements: (int)newSize andSampleRate: (float) newSampleRate {
	self = [super initWithSampleRate: newSampleRate];
	if(self) {
		size = newSize;
		
		fftSize = (int) ceilf(log2f((float) size)) + 1;
		
		realKernel = [XTRealData realDataWithElements:1 << fftSize];
		imaginaryKernel = [XTRealData realDataWithElements:1 << fftSize];
		realOverlap = [XTRealData realDataWithElements:size];
		imaginaryOverlap = [XTRealData realDataWithElements:size];
		
		kernel.realp = [realKernel elements];
		kernel.imagp = [imaginaryKernel elements];
		
		overlap.realp = [realOverlap elements];
		overlap.imagp = [imaginaryOverlap elements];
				
		fftSetup = vDSP_create_fftsetup(fftSize, kFFTRadix2);
		
	}
	return self;
}

-(void)performWithComplexSignal: (XTDSPBlock *)signal {
    // NSLog(@"[%@ %s] Peforming filter\n", [self class], (char *) _cmd);
	[signal performFFT:kFFTDirection_Forward];
	
	//  We must get a lock on the kernel so that if it's being changed due
	//  to a samplerate or filter cutoff operation, we don't stomp on it.
	@synchronized(realKernel) {
		vDSP_zvmul([signal signal], 1, 
				   &kernel, 1, 
				   [signal signal], 1, 
				   1 << fftSize, 1);
	}
	
	[signal performFFT:kFFTDirection_Inverse];
	
	//  We need to scale the inverse FFT by fftSize to compensate for Apple's
	//  implementation of the FFT function.
	float scalingFactor = (float) (1 << fftSize);
	vDSP_vsdiv([signal realElements], 1, 
			   &scalingFactor, 
			   [signal realElements], 1, 
			   1 << fftSize);
	vDSP_vsdiv([signal imaginaryElements], 1, 
			   &scalingFactor, 
			   [signal imaginaryElements], 1, 
			   1 << fftSize);
	
	//  If the block size has changed since the last time we processed one
	//  We increase the overlap buffer to compensate.  It throws away the last
	//  overlap, and this may cause some static, but it's a temporary condition
	//  until the buffer can fill again.
	if([realOverlap elementLength] != [signal blockSize]) {
		NSLog(@"Expanding overlap from %d to %d\n", [realOverlap elementLength], [signal blockSize]);
		realOverlap = [XTRealData realDataWithElements:[signal blockSize]];
		imaginaryOverlap = [XTRealData realDataWithElements:[signal blockSize]];
		overlap.realp = [realOverlap elements];
		overlap.imagp = [imaginaryOverlap elements];
	}
	
	//  Add the overlap and copy the high samples into the overlap buffer for
	//  the next time around.
	vDSP_zvadd([signal signal], 1, 
			   &overlap, 1, 
			   [signal signal], 1, 
			   [signal blockSize]);
	float *realSignalElements = [signal realElements];
	float *imaginarySignalElements = [signal imaginaryElements];
	memcpy(overlap.realp, &(realSignalElements[[signal blockSize]]), [signal blockSize] * sizeof(float));
	memcpy(overlap.imagp, &(imaginarySignalElements[[signal blockSize]]), [signal blockSize] * sizeof(float));    
}

// XXX This is probably broken
-(void)performWithRealSignal: (XTRealData *)signal {
	float *filter = [realKernel elements];
	int filterLength = [realKernel elementLength];
    	
	vDSP_conv([signal elements], 1, 
			  &(filter[filterLength - 1]), -1, 
			  [signal elements], 1, 
			  [signal elementLength], filterLength);
}


-(void)calculateCoefficients {
	[self doesNotRecognizeSelector:_cmd];
}

-(void)setSampleRate:(float)newSampleRate {
	[super setSampleRate:newSampleRate];
	[self calculateCoefficients];
}

	
@end
