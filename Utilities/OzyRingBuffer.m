//
//  OzyRingBuffer.m
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

// $Id: OzyRingBuffer.m 169 2010-11-06 00:36:49Z mcdermj $

#import "OzyRingBuffer.h"

#import <mach/semaphore.h>
#import <mach/task.h>

@implementation OzyRingBuffer

-(id)initWithEntries: (int)_size {
	self = [super init];
	if(self) {
		data = [NSMutableData dataWithLength:_size];
		insertIndex = removeIndex = 0;
		
		sizeLock = [[NSCondition alloc] init];
	}
	
	return self;
}

-(id)initWithEntries: (int)size andName: (NSString *)theName {
	self = [super init];
	if(self) {
		data = [NSMutableData dataWithLength:size];
		insertIndex = removeIndex = 0;
		
		sizeLock = [[NSCondition alloc] init];
		
		name = theName;
	}
	
	return self;
}

-(int)space {
	return [data length] - entries;
}

-(int)entries {
	return entries;
}

-(void)clear {
	@synchronized(data) {
		entries = 0;
		insertIndex = 0;
		removeIndex = 0;
	}
}

-(void)put: (NSData *) _data {
	@synchronized(data) {
		if([self space] < [_data length]) {
			NSLog(@"%@ [OzyRingBuffer put]: space=%d, wanted=%d\n", name, [self space], (int) [_data length]);
			return;
		}
		
		if(insertIndex + [_data length] <= [data length]) {  // We can fit the whole thing in one go.
			[data replaceBytesInRange:NSMakeRange(insertIndex, [_data length]) withBytes:[_data bytes]];
			insertIndex += [_data length];
		} else {
			int firstFragmentLength = [data length] - insertIndex;
			int secondFragmentLength = [_data length] - firstFragmentLength;
			
			[data replaceBytesInRange:NSMakeRange(insertIndex, firstFragmentLength) withBytes: [_data bytes]];
			[data replaceBytesInRange:NSMakeRange(0, secondFragmentLength) withBytes: [[_data subdataWithRange:NSMakeRange(firstFragmentLength, secondFragmentLength)] bytes]];
			insertIndex = secondFragmentLength;
		}
		entries += [_data length];
	}
	
	[sizeLock lock];
	[sizeLock signal];
	[sizeLock unlock];
}

-(NSData *)get: (int)_size {
	@synchronized(data) {
		if(entries < _size) {
			NSLog(@"[OzyRingBuffer get]: wanted=%d, have=%d\n", _size, entries);
			return nil;
		}
		
		if(removeIndex + _size <= [data length]) {
			NSData *outboundData = [data subdataWithRange:NSMakeRange(removeIndex, _size)];
			removeIndex += _size;
			entries -= _size;
			return outboundData;
		} else {
			int firstFragmentLength = [data length] - removeIndex;
			int secondFragmentLength = _size - firstFragmentLength;
			
			NSMutableData *outboundData = [NSMutableData dataWithData:[data subdataWithRange:NSMakeRange(removeIndex, firstFragmentLength)]];
			[outboundData appendData:[data subdataWithRange:NSMakeRange(0, secondFragmentLength)]];
			removeIndex = secondFragmentLength;
			entries -= _size;
			return outboundData;
		}
	}
	
	return nil;
}

-(NSData *)waitForSize: (int) requestedSize {
	[sizeLock lock];
	while(entries < requestedSize) {
		[sizeLock wait];
	}
		
	[sizeLock unlock];
	return [self get: requestedSize];

}
@end
