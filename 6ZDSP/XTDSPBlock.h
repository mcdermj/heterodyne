//
//  XTDSPBlock.h
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

// $Id: XTDSPBlock.h 141 2010-03-18 21:19:57Z mcdermj $

#import <Cocoa/Cocoa.h>

#import <Accelerate/Accelerate.h>

#import "XTRealData.h"

@interface XTDSPBlock : NSObject {
	XTRealData *real;
	XTRealData *imaginary;
	int blockSize;
	int fftSize;
	DSPSplitComplex signal;
	
	FFTSetup fftSetup;
}

@property (readonly) int blockSize;
@property (readonly) float *realElements;
@property (readonly) float *imaginaryElements;
@property (readonly) DSPSplitComplex *signal;

-(id)initWithBlockSize: (int)newBlockSize;
+(XTDSPBlock *)dspBlockWithBlockSize: (int)newBlockSize;
-(float *)realElements;
-(float *)imaginaryElements;
-(void)performFFT: (FFTDirection) direction;
-(void)clearBlock;

@end
