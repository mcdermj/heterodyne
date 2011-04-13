//
//  XTDSPFixedGain.m
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

// $Id: XTDSPFixedGain.m 243 2011-04-13 14:40:14Z mcdermj $

#import "XTDSPFixedGain.h"

#import "XTDSPBlock.h"

@implementation XTDSPFixedGain

@synthesize gain;

-(id)initWithGain: (float)newGain {
	self = [super init];
	if(self) {
		gain = newGain;
	}
	return self;
}

-(void)performWithComplexSignal: (XTDSPBlock *)signal {
	float *realValues = [signal realElements];
	float *imaginaryValues = [signal imaginaryElements];

	vDSP_vsmul(realValues, 1,
			   &gain,
			   realValues, 1,
			   [signal blockSize]);
	vDSP_vsmul(imaginaryValues, 1,
			   &gain,
			   imaginaryValues, 1,
			   [signal blockSize]);	
}

-(void)setDBGain:(float)dBGain {
    self.gain = powf(10.0f, dBGain / 20.0f);
}

-(float)dBGain {
    return 20.0f * logf(gain);
}

@end
