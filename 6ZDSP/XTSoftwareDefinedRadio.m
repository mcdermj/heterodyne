//
//  XTSoftwareDefinedRadio.m
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

// $Id: XTSoftwareDefinedRadio.m 243 2011-04-13 14:40:14Z mcdermj $

#import "XTSoftwareDefinedRadio.h"

#import <Accelerate/Accelerate.h>

#include <OpenCl/cl_ext.h>

#import "XTDSPAMDemodulator.h"
#import "XTDSPModule.h"
#import "XTDSPFixedGain.h"
#import "XTDSPSpectrumTap.h"
#import "XTDSPBandpassFilter.h"
#import "XTDSPAutomaticGainControl.h"
#import "XTWorkerThread.h"

@implementation XTSoftwareDefinedRadio

@synthesize sampleRate;

-(id)init {
	self = [super init];
	if(self) {		
		dspModules = [[NSMutableArray alloc] init];	
		
		spectrumTap = [[XTDSPSpectrumTap alloc] initWithSampleRate: sampleRate andSize: 4096];	
		[dspModules addObject:spectrumTap];
		ifFilter = [[XTDSPBandpassFilter alloc] initWithSize:1023
												  sampleRate:sampleRate 
												   lowCutoff:-6000.0 
											   andHighCutoff:6000.0];
		[dspModules addObject:ifFilter];
		
		agc = [[XTDSPAutomaticGainControl alloc] initWithSampleRate:sampleRate];
		[dspModules addObject:agc];
		
		[dspModules addObject:[[XTDSPAMDemodulator alloc] init]];
		
		
		//[dspModules addObject:[[XTDSPFixedGain alloc] initWithGain:0.05]];
		
		workerThread = [[XTWorkerThread alloc] initWithRealtime:YES];
		
		//[self initOpenCL]; 	
	}
	return self;	
}

-(void)awakeFromNib {
	
	// [dspModules addObject:[[XTDSPFixedGain alloc] initWithGain:100.0]];
	
	NSLog(@"Module stack has %ld entries\n", [dspModules count]);
	
	[workerThread start];
	
}

-(id)initWithSampleRate: (float)initialSampleRate {
	self = [super init];
	if(self) {
		sampleRate = initialSampleRate;
				
		dspModules = [[NSMutableArray alloc] init];
		
		spectrumTap = [[XTDSPSpectrumTap alloc] initWithSampleRate: sampleRate andSize: 4096];
		if(spectrumTap == NULL || spectrumTap == nil) {
			NSLog(@"SpectrumTap didn't allocate\n");
		}
		
		[dspModules addObject:spectrumTap];
		[dspModules addObject:[[XTDSPBandpassFilter alloc] initWithSize:1024
															 sampleRate:sampleRate 
															  lowCutoff:0.0f 
														  andHighCutoff:2700.0f]];
        [dspModules addObject:[[XTDSPAutomaticGainControl alloc] initWithSampleRate:sampleRate]];

		// [dspModules addObject:[[XTDSPAMDemodulator alloc] init]];
		//[dspModules addObject:[[XTDSPFixedGain alloc] initWithGain:0.25f]];
		
		NSLog(@"Module stack has %ld entries\n", [dspModules count]);
		
		workerThread = [[XTWorkerThread alloc] initWithRealtime:YES];
		[workerThread start];
		
		//[self initOpenCL]; 
	}
	return self;
}

-(void)processComplexSamples: (XTDSPBlock *)complexData {
	for(XTDSPModule *module in dspModules) {
		BOOL wait = [dspModules lastObject] == module ? YES : NO;
		
		[module performSelector: @selector(performWithComplexSignal:) 
					   onThread: workerThread 
					 withObject: complexData
				  waitUntilDone: wait];
	}	
}

-(void)tapSpectrumWithRealData: (XTRealData *)spectrumData {
	[spectrumTap tapBufferWithRealData:spectrumData];
}

-(void)setHighCut: (float)highCutoff {
	[ifFilter setHighCut:highCutoff];
}

-(void)setLowCut: (float)lowCutoff {
	[ifFilter setLowCut:lowCutoff];
}

-(void)setSampleRate:(float)newSampleRate {
	sampleRate = newSampleRate;
	for(XTDSPModule *module in dspModules) {
		[module setSampleRate:newSampleRate];
	}
}

-(void)initOpenCL {
	int openClError;
	cl_device_id openClDevices[10];
	cl_uint returnedClDevices;
	int i;
	
	//  First let's see what devices we have out there
	openClError = clGetDeviceIDs(NULL, CL_DEVICE_TYPE_CPU, 10, openClDevices, &returnedClDevices);
	
	if(openClError != CL_SUCCESS) {
		NSLog(@"Coudln't get the OpenCL Devices: %d\n", openClError);
		return;
	}
	
	NSLog(@"Enumerating %d OpenCL Devices:\n", returnedClDevices);
	
	for(i = 0; i < returnedClDevices; ++i) {
		char deviceName[256];
		char deviceVendor[256];
		size_t deviceNameSize = 256;
		cl_uint clockRate;
		
		openClError = clGetDeviceInfo(openClDevices[i], CL_DEVICE_NAME, 256, (void *) deviceName, &deviceNameSize);
		if(openClError != CL_SUCCESS) {
			NSLog(@"Couldn't enumerate OpenCL Devices: %d\n", openClError);
			return;
		}
		deviceName[deviceNameSize] = '\0';
		
		openClError = clGetDeviceInfo(openClDevices[i], CL_DEVICE_VENDOR, 256, (void *) deviceVendor, &deviceNameSize);
		if(openClError != CL_SUCCESS) {
			NSLog(@"Couldn't enumerate OpenCL Devices: %d\n", openClError);
			return;
		}
		deviceVendor[deviceNameSize] = '\0';
		
		openClError = clGetDeviceInfo(openClDevices[i], CL_DEVICE_MAX_CLOCK_FREQUENCY, sizeof(cl_uint), (void *) &clockRate, NULL);
		if(openClError != CL_SUCCESS) {
			NSLog(@"Couldn't enumerate OpenCL Devices: %d\n", openClError);
			return;
		}
		
		NSLog(@"\tDevice: %s %s @ %d MHz\n", deviceVendor, deviceName, clockRate);
	}
	
	openClContext = clCreateContext(0, returnedClDevices, openClDevices, &clLogMessagesToSystemLogAPPLE, NULL, &openClError);
	if(openClError != CL_SUCCESS) {
		NSLog(@"Couldn't create an OpenCL Context: %d\n", openClError);
		return;
	}
}

@end
