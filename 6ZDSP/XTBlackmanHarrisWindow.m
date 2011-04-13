//
//  XTBlackmanHarrisWindow.m
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

// $Id: XTBlackmanHarrisWindow.m 141 2010-03-18 21:19:57Z mcdermj $

#import "XTBlackmanHarrisWindow.h"

@implementation XTBlackmanHarrisWindow

-(id)initWithElements:(int) size {
	self = [super init];
	if(self) {
		float a0 = 0.35875F;
		float a1 = 0.48829F;
		float a2 = 0.14128F;
		float a3 = 0.01168F;
		
		float twopi = M_PI * 2.0F;
		float fourpi = M_PI * 4.0F;
		float sixpi = M_PI * 6.0F;
		
		int i;
		
		filterData = [NSMutableData dataWithLength:size * sizeof(float)];
		float *filter = [filterData mutableBytes];
		
		for(i = 0;i < size; i++) {
			filter[i] = a0
			- a1 * cosf(twopi * (float) (i) / (float) (size - 1))
			+ a2 * cosf(fourpi * (float) (i) / (float) (size - 1))
			- a3 * cosf(sixpi * (float) (i) / (float) (size - 1));
		}
	}
	return self;
}

+(XTBlackmanHarrisWindow *)blackmanHarrisWindowWithElements:(int) size {
    return [[XTBlackmanHarrisWindow alloc] initWithElements: size];	
}


-(const void *)bytes {
	return [filterData bytes];
}

-(int)elementLength {
	return [filterData length] / sizeof(float);
}


@end
