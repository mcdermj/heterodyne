//
//  XTDTTSP.m
//  Heterodyne
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

// $Id:$

#import "XTDTTSP.h"

#import "XTHeterodyneHardwareDriver.h"
#import "SystemAudio.h"
#import "OzyRingBuffer.h"
#import "XTSoftwareDefinedRadio.h"
#import "XTDSPBlock.h"

@implementation XTDTTSP

@synthesize sampleRate;
@synthesize mux;

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

-(id)init {
	self = [super init];
	
	if(self) {		
		systemAudioState = NO;
		
		sampleBufferData = [NSMutableData dataWithLength:sizeof(float) * 2048];
		sampleBuffer = (DSPComplex *) [sampleBufferData mutableBytes];
		
		sampleRate = 192000;
        
        mainReciver = [[XTSoftwareDefinedRadio alloc] initWithSampleRate:(float) sampleRate];
        processingBlock = [[XTDSPBlock alloc] initWithBlockSize:1024];

	}
	
	return self;
}

-(void)start {
	[self loadParams];

	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(newSampleRate:)
												 name:@"XTSampleRateChanged"
											   object: nil];
	
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector: @selector(loadParams) 
												 name: NSUserDefaultsDidChangeNotification 
											   object: nil];	
}

-(void)stop {
	systemAudioState = NO;
	[audioThread stop];
	
	[[NSNotificationCenter defaultCenter] removeObserver:self forKeyPath:@"XTSampleRateChanged"];
	[[NSNotificationCenter defaultCenter] removeObserver:self forKeyPath: NSUserDefaultsDidChangeNotification];
}

-(void)audioCallbackForThread: (int)thread realIn:(float *)realIn imagIn:(float *)imagIn realOut:(float *)realOut imagOut:(float *)imagOut size:(int)size {
	
	if(thread != 0) return;
    
    [processingBlock clearBlock];
    memcpy([processingBlock realElements], realIn, sizeof(float) * 1024);
    memcpy([processingBlock imaginaryElements], imagIn, sizeof(float) * 1024);
    
    [mainReciver processComplexSamples:processingBlock];
    
    memcpy(realOut, [processingBlock realElements], sizeof(float) * 1024);
    memcpy(imagOut, [processingBlock imaginaryElements], sizeof(float) * 1024);
	
	systemSamples.realp = realOut;
	systemSamples.imagp = imagOut;
	
	vDSP_ztoc(&systemSamples, 1, sampleBuffer, 2, 1024);
	
	if(audioThread.running == YES) {
		[audioBuffer put:sampleBufferData];
	}
	
}

-(void)processBlock:(XTDSPBlock *)block {
    [mainReciver processComplexSamples:block];
    
    vDSP_ztoc([block signal], 1, sampleBuffer, 2, 1024);
    if(audioThread.running == YES) {
		[audioBuffer put:sampleBufferData];
	}
}

-(void) resetDSP {
}

-(void)newSampleRate:(NSNotification *)notification {
	NSObject <XTHeterodyneHardwareDriver> *interface = [notification object];
	
	[self setSampleRate:[interface sampleRate]];
	[mainReciver setSampleRate:(float)[interface sampleRate]];
	
	//  We should actually change the DTTSP sample rate here rather than in TranceiverController
	//  This has to wait until wet get the DTTSP parameters on this object rather than over there
}

-(void)tapSpectrumWithRealData:(XTRealData *)data {
    [mainReciver tapSpectrumWithRealData:data];
}

@end
