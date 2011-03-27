//
//  OzyInputBuffers.m
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

// $Id: OzyInputBuffers.m 169 2010-11-06 00:36:49Z mcdermj $

#import "OzyInputBuffers.h"

#include "utils-probes.h"

@implementation OzyInputBuffers

@synthesize ozyInputBufferSemaphore;

-(id)initWithSize:(int)requestedSize quantity:(int)requestedQuantity {
	int i;
	
	self = [super init];
	
	if(self) {
		@synchronized(bufferList) {
			bufferList = [[NSMutableArray alloc] init];
		}
		
		@synchronized(freeList) {
			freeList = [[NSMutableArray alloc] initWithCapacity:requestedQuantity];
			
			for(i = 0; i < requestedQuantity; ++i) {
				[freeList insertObject: [[NSMutableData alloc] initWithLength:requestedSize] atIndex: 0];
			}
		}
		semaphore_create(mach_task_self(), &ozyInputBufferSemaphore, SYNC_POLICY_FIFO, 0);
	}
	
	return self;
}

-(NSData *)getInputBuffer {
	NSData *returnBuffer;
	
	if([bufferList count] == 0) {
		NSLog(@"No input buffers remain\n");
        BUFFERS_BLOCKBUFFER_GET([bufferList count], [freeList count]);
		return NULL;
	}
		
	@synchronized(bufferList) {
		returnBuffer = [bufferList lastObject];
		[bufferList removeLastObject];
	}
	
    BUFFERS_BLOCKBUFFER_GET([bufferList count], [freeList count]);

	return returnBuffer;
}

-(void)putInputBuffer:(NSData *)inputBuffer {
	@synchronized(bufferList) {
		[bufferList insertObject:inputBuffer atIndex:0];
	}
}

-(NSMutableData *)getFreeBuffer {
	NSMutableData *freeBuffer;
	
	if([freeList count] == 0) {
		NSLog(@"No free buffers remain\n");
		return NULL;
	}
	
	@synchronized(freeList) {
		freeBuffer = [freeList lastObject];
		[freeList removeLastObject];
	}
				
	return freeBuffer;
}

-(void)freeBuffer:(NSData *)freeBuffer {
	@synchronized(freeList) {
		[freeList insertObject:freeBuffer atIndex:0];
	}
}

-(int)usedBuffers {
	return [bufferList count];
}

@end
