//
//  XTDSPSpectrumTap.m
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

// $Id: XTDSPSpectrumTap.m 243 2011-04-13 14:40:14Z mcdermj $

#import <Accelerate/Accelerate.h>

#import "XTDSPSpectrumTap.h"
#import "XTDSPBlock.h"
#import "XTRealData.h"
#import "XTBlackmanHarrisWindow.h"

@implementation XTDSPSpectrumTap

-(id)initWithSampleRate:(float)newSampleRate andSize: (int)elements {
	self = [super initWithSampleRate:newSampleRate];
	if(self) {		
		realTapBuffer = [XTRealData realDataWithElements:elements];
		imaginaryTapBuffer = [XTRealData realDataWithElements:elements];
		
		realWorkBuffer = [XTRealData realDataWithElements: elements];
		imaginaryWorkBuffer = [XTRealData realDataWithElements:elements];
		
		fftOut.realp = [realWorkBuffer elements];
		fftOut.imagp = [imaginaryWorkBuffer elements];
		
		fftSize = (int) ceilf(log2f((float) (elements)));
		fftSetup = vDSP_create_fftsetup(fftSize, kFFTRadix2);	
		
		window = [XTBlackmanHarrisWindow blackmanHarrisWindowWithElements:elements];
		bufferRange = NSMakeRange(0, elements);
		copyRange = NSMakeRange(0, 1024);
	}
	return self;
}

-(void)performWithComplexSignal:(XTDSPBlock *)signal {
	float *realTap = [realTapBuffer elements];
	float *imaginaryTap = [imaginaryTapBuffer elements];
	
	copyRange.length = [signal blockSize];
	NSRange intersectionRange = NSIntersectionRange(bufferRange, copyRange);
	@synchronized(realTapBuffer) {
		DSPSplitComplex ringBuffer;
		ringBuffer.realp = &(realTap[intersectionRange.location]);
		ringBuffer.imagp = &(imaginaryTap[intersectionRange.location]);
		vDSP_zvmov([signal signal], 1, &ringBuffer, 1, intersectionRange.length);
		copyRange.location += intersectionRange.length;
				
		if(intersectionRange.length != [signal blockSize]) {
			intersectionRange.location = 0;
			copyRange.location = 0;
			intersectionRange.length = [signal blockSize] - intersectionRange.length;
			ringBuffer.realp = &(realTap[intersectionRange.location]);
			ringBuffer.imagp = &(imaginaryTap[intersectionRange.location]);
			vDSP_zvmov([signal signal], 1, &ringBuffer, 1, intersectionRange.length);
			copyRange.location += intersectionRange.length;
		}
		
	}
}

-(void)tapBufferWithRealData: (XTRealData *) destinationData {
	[realWorkBuffer clearElements];
	[imaginaryWorkBuffer clearElements];
	
	@synchronized(realTapBuffer) {
		memcpy(fftOut.realp, [realTapBuffer elements], [realTapBuffer elementLength]);
		memcpy(fftOut.imagp, [imaginaryTapBuffer elements], [imaginaryTapBuffer elementLength]);
	}
	
	vDSP_vmul(fftOut.realp, 1, [window bytes], 1, fftOut.realp, 1, [window elementLength]);
	vDSP_vmul(fftOut.imagp, 1, [window bytes], 1, fftOut.imagp, 1, [window elementLength]);
	
	vDSP_fft_zip(fftSetup, &fftOut, 1,
				 fftSize, kFFTDirection_Forward);
			
	int length = [destinationData elementLength] > [realTapBuffer elementLength] ? 
	[realTapBuffer elementLength] : [destinationData elementLength];
	
	[destinationData clearElements];
	vDSP_zvmags(&fftOut, 1,
				[destinationData elements], 1,
				length);
	
	float scaleFactor = 1e-60;
	float *dest = [destinationData elements];
	
	//  I don't know why we add this scaling factor...
	//vDSP_vsadd([destinationData elements], 1, &scaleFactor, [destinationData elements], 1, length);

	vDSP_vrvrs([destinationData elements], 1, length / 2);
	vDSP_vrvrs(&(dest[length / 2]), 1, length / 2);
			
	float zeroReference = 4.0f;
	vDSP_vdbcon([destinationData elements], 1,
				&zeroReference,
				[destinationData elements], 1,
				length, 0);
	
	//  Clip weird values
	float highClip = 0.0;
	float lowClip = -200.0;
	vDSP_vclip([destinationData elements], 1, &lowClip, &highClip, [destinationData elements], 1, length);
	
	//  Should reflect the variable blockSize value
	/* float filterCorrection = -3.0f * (11.0f - log10f(4092.0f));
	vDSP_vsadd([destinationData elements], 1, &filterCorrection, [destinationData elements], 1, length); */
}

@end
