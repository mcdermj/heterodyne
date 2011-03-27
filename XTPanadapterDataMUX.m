//
//  XTPanadapterDataMUX.m
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

// $Id$

#import "XTPanadapterDataMUX.h"

#import <mach/mach_time.h>

#include "dttsp.h"


@implementation XTPanadapterDataMUX

@synthesize receiveCalibrationOffset;

-(id)init {
	self = [super init];
	if(self) {		
		initAverage = TRUE; 
		filterCalibrationOffset = 3.0f * (11.0f - log10f(1024.0f));
		preampOffset = -20.0;
		smoothingFactor = 13;
		
		spectrumBuffer = malloc(SPECTRUM_BUFFER_SIZE * sizeof(float));
		averageBuffer = malloc(SPECTRUM_BUFFER_SIZE * sizeof(float));
		smoothBuffer = malloc(SPECTRUM_BUFFER_SIZE * sizeof(float));

		kernel.realp = malloc(SPECTRUM_BUFFER_SIZE * sizeof(float));
		kernel.imagp = malloc(SPECTRUM_BUFFER_SIZE * sizeof(float));
		vDSP_vclr(kernel.realp, 1, SPECTRUM_BUFFER_SIZE);
		vDSP_vclr(kernel.imagp, 1, SPECTRUM_BUFFER_SIZE);

		fftIn.realp = malloc(SPECTRUM_BUFFER_SIZE * sizeof(float));
		fftIn.imagp = malloc(SPECTRUM_BUFFER_SIZE * sizeof(float));
		vDSP_vclr(fftIn.realp, 1, SPECTRUM_BUFFER_SIZE);
		vDSP_vclr(fftIn.imagp, 1, SPECTRUM_BUFFER_SIZE);
		
		float filterValue = 1.0f / (float) smoothingFactor;
		vDSP_vfill(&filterValue, kernel.realp + ((SPECTRUM_BUFFER_SIZE / 2) - ((smoothingFactor - 1) / 2)), 1, smoothingFactor);
		
		fftSetup = vDSP_create_fftsetup(12, kFFTRadix2);
		vDSP_fft_zip(fftSetup, &kernel, 1, 12, kFFTDirection_Forward);
		
		bufferLock = [[NSLock alloc] init];
	}
	
	return self;
}

-(void)awakeFromNib {
	[NSThread detachNewThreadSelector:@selector(threadMain) 
							 toTarget:self 
						   withObject:nil];
	
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(defaultsChanged:) 
												 name: NSUserDefaultsDidChangeNotification 
											   object: nil];
	
	self.receiveCalibrationOffset = [[NSUserDefaults standardUserDefaults] floatForKey:@"receiveCalibrationOffset"];
}

-(void)defaultsChanged: (NSNotification *) notification {
	if([notification name] == NSUserDefaultsDidChangeNotification) {
		self.receiveCalibrationOffset = [[NSUserDefaults standardUserDefaults] floatForKey:@"receiveCalibrationOffset"];
	}
}

-(NSData *) smoothBufferData {
	NSData *bufferData;
	[bufferLock lock];
	bufferData = [NSData dataWithBytes:smoothBuffer length:SPECTRUM_BUFFER_SIZE * sizeof(float)];
	[bufferLock unlock];
	return bufferData;
}

-(NSData *) rawData {
	NSData *bufferData;
	[bufferLock lock];
		bufferData = [NSData dataWithBytes:averageBuffer length:SPECTRUM_BUFFER_SIZE * sizeof(float)];
	[bufferLock unlock];
	return bufferData;
}

-(void) threadMain {
	uint64_t startTime;
	int64_t timeleft;
	static mach_timebase_info_data_t tbi;
	double timeScale;
		
	mach_timebase_info(&tbi);
	timeScale = ((double) tbi.numer / (double) tbi.denom);
		
	float scaling = 0.66;
	
	while(1) {
		
		startTime = mach_absolute_time();
		
		Process_Panadapter(0, spectrumBuffer);
		
		if ([bufferLock lockBeforeDate:[NSDate dateWithTimeIntervalSinceNow:1.0]] == YES) {
			if(initAverage == YES) {
				memcpy(averageBuffer, spectrumBuffer, SPECTRUM_BUFFER_SIZE * sizeof(float));
				initAverage = NO;
			} else {
				vDSP_vavlin(spectrumBuffer, 1, &scaling, averageBuffer, 1, SPECTRUM_BUFFER_SIZE);
			}
			
			vDSP_vclr(fftIn.realp, 1, SPECTRUM_BUFFER_SIZE);
			vDSP_vclr(fftIn.imagp, 1, SPECTRUM_BUFFER_SIZE);
			memcpy(fftIn.realp, averageBuffer, SPECTRUM_BUFFER_SIZE * sizeof(float));

			//  Perform a convolution by doing an FFT and multiplying.
			vDSP_fft_zip(fftSetup, &fftIn, 1, 12, kFFTDirection_Forward);
			vDSP_zvmul(&fftIn, 1, &kernel, 1, &fftIn, 1, SPECTRUM_BUFFER_SIZE, 1);
			vDSP_fft_zip(fftSetup, &fftIn, 1, 12, kFFTDirection_Inverse);

			//  We have to divide by the scaling factor to account for the offset
			//  in the inverse FFT.
			float scale = (float) SPECTRUM_BUFFER_SIZE;
			vDSP_vsdiv(fftIn.realp, 1, &scale, fftIn.realp, 1, SPECTRUM_BUFFER_SIZE);
			
			//  Flip the sides since the center frequency is at the edges because
			//  our filter kernel is centered.
			memcpy(smoothBuffer, fftIn.realp + (SPECTRUM_BUFFER_SIZE / 2), (SPECTRUM_BUFFER_SIZE / 2) * sizeof(float));
			memcpy(smoothBuffer + (SPECTRUM_BUFFER_SIZE / 2), fftIn.realp, (SPECTRUM_BUFFER_SIZE / 2) * sizeof(float));
			
			//  Apply any user calibration
			vDSP_vsadd(smoothBuffer, 1, &receiveCalibrationOffset, smoothBuffer, 1, SPECTRUM_BUFFER_SIZE);
						
			[bufferLock unlock];
			[[NSNotificationCenter defaultCenter] postNotificationName:@"XTPanAdapterDataReady" object:self];
		} else {
			NSLog(@"[XTPanadapterDataMUX threadMain]: Couldn't acquire buffer lock\n");
		}
		
		// timeleft = 60000000 - ((mach_absolute_time() - startTime) * timeScale);
		timeleft = 33333333 - ((mach_absolute_time() - startTime) * timeScale);
		
		if(timeleft / 1000 > 1) {
			usleep(timeleft / 1000);
		}
	}
}

@end