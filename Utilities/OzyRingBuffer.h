//
//  OzyRingBuffer.h
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

// $Id: OzyRingBuffer.h 169 2010-11-06 00:36:49Z mcdermj $


#import <Cocoa/Cocoa.h>


@interface OzyRingBuffer : NSObject {
	NSMutableData *data;
	unsigned int insertIndex, removeIndex, entries;
	
	NSCondition *sizeLock;
	
	NSString *name;
}

-(id)initWithEntries: (int)_size;
-(id)initWithEntries: (int)size andName:(NSString *)theName;
-(int)space;
-(int)entries;
-(void)put:(NSData *)_data;
-(NSData *)get:(int)_size;
-(NSData *)waitForSize: (int) requestedSize;
-(NSData *)waitForSize: (int) requestedSize withTimeout:(NSDate *)timeout;
-(void)clear;

@end
