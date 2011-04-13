//
//  XTDSPBlock.m
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

// $Id: XTDSPBlock.m 243 2011-04-13 14:40:14Z mcdermj $

#import "XTDSPBlock.h"

@implementation XTDSPBlock

@synthesize blockSize;

-(id)initWithBlockSize: (int)newBlockSize {
	self = [super init];
	if(self) {
		real = [XTRealData realDataWithElements:2 * newBlockSize];
		imaginary = [XTRealData realDataWithElements:2 * newBlockSize];
		blockSize = newBlockSize;
		
		signal.realp = [real elements];
		signal.imagp = [imaginary elements];
		
		fftSize = (int) ceilf(log2f((float) (2 * blockSize)));
		// NSLog(@"[%@ %s]: Setting up DSP Block FFT for size %d\n", [self class], (char *) _cmd, fftSize);
		fftSetup = vDSP_create_fftsetup(fftSize, kFFTRadix2);
	}
	return self;
}

+(XTDSPBlock *)dspBlockWithBlockSize: (int)newBlockSize {
	return [[XTDSPBlock alloc] initWithBlockSize:newBlockSize];
}

-(float *)realElements {
	return [real elements];
}

-(float *)imaginaryElements {
	return [imaginary elements];
}

-(void)performFFT: (FFTDirection) direction {	
	vDSP_fft_zip(fftSetup, &signal, 1, fftSize, direction);
}

-(DSPSplitComplex *)signal {
	return &signal;
}

-(void)clearBlock {
	[real clearElements];
	[imaginary clearElements];
	
	signal.realp = [real elements];
	signal.imagp = [imaginary elements];
}

@end
