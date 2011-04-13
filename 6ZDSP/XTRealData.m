//
//  XTRealData.m
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

// $Id: XTRealData.m 141 2010-03-18 21:19:57Z mcdermj $

#import "XTRealData.h"


@implementation XTRealData

@synthesize data;

-(id)initWithElements:(int)size {
	self = [super init];
	if(self) {
		data = [NSMutableData dataWithLength:size * sizeof(float)];
	}
	return self;
}

-(id)initWithRealData:(XTRealData *)realData {
	self = [super init];
	if(self) {
		data = [NSMutableData dataWithData:[realData data]];
	}
	return self;
}

+(XTRealData *)realDataWithElements: (int) size {
	return [[XTRealData alloc] initWithElements: size];
}

+(XTRealData *)realDataWithRealData:(XTRealData *)realData {
	return [[XTRealData alloc] initWithRealData:realData];
}

-(float *)elements {
	return (float *) [data mutableBytes];
}

-(int)elementLength {
	return [data length] / sizeof(float);
}

-(void)setElementLength: (int) newLength {
	[data setLength:newLength * sizeof(float)];
}

-(int)length {
	return [data length];
}

-(void)clearElements {
	[data resetBytesInRange:NSMakeRange(0, [data length])];
}

@end
