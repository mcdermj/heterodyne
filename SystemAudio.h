//
//  SystemAudioThread.h
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

#import <Cocoa/Cocoa.h>

#import <AudioToolbox/AudioQueue.h>
#import <CoreAudio/CoreAudio.h>
#import <AudioToolbox/AudioToolbox.h>

#define SYSTEM_AUDIO_BUFFERS 4

@class XTAudioUnitGraph;
@class XTAudioUnit;
@class XTOutputAudioUnit;
@class OzyRingBuffer;

@interface SystemAudio : NSObject	{
	OzyRingBuffer *buffer;
		
	XTAudioUnitGraph *audioGraph;
	XTAudioUnit *equalizerAudioUnit;
	XTOutputAudioUnit *defaultOutputUnit;
		
	BOOL running;
	
	int sampleRate;
}

@property BOOL running;
@property int sampleRate;

-(id)initWithBuffer:(OzyRingBuffer *)_buffer andSampleRate:(int)sampleRate;
-(void)start;
-(void)stop;
-(void)auProperties;

@end