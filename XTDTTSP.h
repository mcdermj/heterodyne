//
//  XTDTTSP.h
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

#import <Cocoa/Cocoa.h>

#include <Accelerate/Accelerate.h>

@class SystemAudio;
@class OzyRingBuffer;

@interface XTDTTSP : NSObject {
	
	BOOL systemAudioState;
	SystemAudio *audioThread;
	OzyRingBuffer *audioBuffer;
	
	DSPSplitComplex systemSamples;
	NSMutableData *sampleBufferData;
	DSPComplex *sampleBuffer;
	
	// ivars
	int sampleRate;

}

@property int sampleRate;

-(void)audioCallbackForThread: (int)thread realIn:(float *)realIn imagIn:(float *)imagIn realOut:(float *)realOut imagOut:(float *)imagOut size:(int)size;
-(void)start;
-(void)stop;
@end
