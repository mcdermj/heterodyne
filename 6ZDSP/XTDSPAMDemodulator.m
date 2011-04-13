//
//  XTDSPAMDemodulator.m
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

// $Id: XTDSPAMDemodulator.m 243 2011-04-13 14:40:14Z mcdermj $

#import "XTDSPAMDemodulator.h"
#import "XTDSPBlock.h"
#import "XTRealData.h"

#import <Accelerate/Accelerate.h>

@implementation XTDSPAMDemodulator

-(id)init {
	self = [super init];
	if(self) {
		dc = 0.0;
		smooth = 0.0;
		
		magnetudes = [XTRealData realDataWithElements:1];
	}
	return self;
}

-(void)performWithComplexSignal: (XTDSPBlock *)signal {
	int i;
    // float averageEnvelope;

	if([magnetudes elementLength] != [signal blockSize] * 2) {
		[magnetudes setElementLength:[signal blockSize] * 2];
	}
	
	float *magElements = [magnetudes elements];
	float *realElements = [signal realElements];
	float *imaginaryElements = [signal imaginaryElements];	
	
	vDSP_ztoc([signal signal], 1, 
			  (DSPComplex *) magElements, 2, 
			  [signal blockSize]);
	
	vDSP_polar([magnetudes elements], 2, 
			   [magnetudes elements], 2, 
			   [signal blockSize]);
    
    /*
    vDSP_meanv([magnetudes elements], 2, 
               &averageEnvelope, 
               [signal blockSize]);
    averageEnvelope = -averageEnvelope;
    
    vDSP_vsadd([magnetudes elements], 2, &averageEnvelope, realElements, 1, [signal blockSize]);
    memcpy(imaginaryElements, realElements, sizeof(float) * [signal blockSize]);
    
    return; */
	
	for(i = 0; i < [magnetudes elementLength]; i += 2) {
		dc = (0.9999f * dc) + (0.0001f * magElements[i]);
		smooth = (0.5f * smooth) + (0.5f * (magElements[i] - dc));
		realElements[i / 2] =  imaginaryElements[i / 2] = smooth;
	}
}

@end
