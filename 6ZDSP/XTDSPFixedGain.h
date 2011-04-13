//
//  XTDSPFixedGain.h
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

// $Id: XTDSPFixedGain.h 243 2011-04-13 14:40:14Z mcdermj $

#import <Cocoa/Cocoa.h>

#import "XTDSPModule.h"

@interface XTDSPFixedGain : XTDSPModule {
	float gain;
}

-(id)initWithGain: (float)newGain;

@property float gain;
@property float dBGain;

@end
