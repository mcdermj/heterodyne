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

#import "XTReceiver.h"
#import "XTDSPSpectrumTap.h"
#import "XTDSPBlock.h"
#import "OzyRingBuffer.h"
#import "SystemAudio.h"

@implementation XTSoftwareDefinedRadio

@synthesize sampleRate;

-(void)loadParams {
	BOOL newSystemAudioState = [[NSUserDefaults standardUserDefaults] boolForKey:@"systemAudio"];
	
	if(newSystemAudioState == systemAudioState) return;
	
	if(newSystemAudioState == YES) {
		audioBuffer = [[OzyRingBuffer alloc] initWithEntries:sizeof(float) * 2048 * 16 andName: @"audio"];
		audioThread = [[SystemAudio alloc] initWithBuffer:audioBuffer andSampleRate: sampleRate];
		[audioThread start];
	}
	
	if(newSystemAudioState == NO) {
		[audioThread stop];
	}
	
	systemAudioState = newSystemAudioState;
}

-(id)initWithSampleRate: (float)initialSampleRate {
	self = [super init];
	if(self) {
		sampleRate = initialSampleRate;
        
        systemAudioState = NO;
		
		sampleBufferData = [NSMutableData dataWithLength:sizeof(float) * 2048];
		sampleBuffer = (DSPComplex *) [sampleBufferData mutableBytes];
				
		receivers = [NSMutableArray arrayWithCapacity:1];
        [receivers addObject:[[XTReceiver alloc] initWithSampleRate:sampleRate]];
		
		spectrumTap = [[XTDSPSpectrumTap alloc] initWithSampleRate: sampleRate andSize: 4096];
        
        receiverCondition = [[NSCondition alloc] init];
	}
	return self;
}

-(void)start {
	[self loadParams];
	
	[[NSNotificationCenter defaultCenter] addObserver: self 
											 selector: @selector(loadParams) 
												 name: NSUserDefaultsDidChangeNotification 
											   object: nil];	
}

-(void)stop {
	systemAudioState = NO;
	[audioThread stop];
	
	[[NSNotificationCenter defaultCenter] removeObserver:self forKeyPath: NSUserDefaultsDidChangeNotification];
}

-(void)completionCallback {
    [receiverCondition lock];
    --pendingReceivers;
    [receiverCondition signal];
    [receiverCondition unlock];
}

-(void)processComplexSamples: (XTDSPBlock *)complexData {
    [spectrumTap performWithComplexSignal:complexData];
    
    [receiverCondition lock];
    
    pendingReceivers = [receivers count];
    
    for(XTReceiver *receiver in receivers) 
        [receiver processComplexSamples:complexData withCompletionSelector:@selector(completionCallback) onObject:self];

    while(pendingReceivers > 0)
        [receiverCondition wait];
    
    [receiverCondition unlock];
    
    //  Copy signal into the audio buffer
    if(audioThread.running == YES) {
        //  XXX Check for overflow of sample buffer!
        vDSP_ztoc([complexData signal], 1, sampleBuffer, 2, [complexData blockSize]);
		[audioBuffer put:sampleBufferData];
	}
}

-(void)tapSpectrumWithRealData: (XTRealData *)spectrumData {
	[spectrumTap tapBufferWithRealData:spectrumData];
}

-(void)setSampleRate:(float)newSampleRate {
	sampleRate = newSampleRate;
	for(XTReceiver *receiver in receivers) {
		[receiver setSampleRate:newSampleRate];
	}
}

/*
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
} */

@end
