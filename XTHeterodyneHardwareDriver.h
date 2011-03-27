//
//  XTHeterodyneHardwareDriver.h
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

// $Id: OzyInterface.h 171 2010-11-15 23:49:08Z mcdermj $

#import <Cocoa/Cocoa.h>

@class XTDTTSP;

@protocol XTHeterodyneHardwareDriver

@property (readonly) NSView *configWindow;
//  This should be read only and the interface should control sample rate
@property int sampleRate;
@property XTDTTSP *sdr;

+(NSString *)name;
+(float)version;
+(NSString *)versionString;
+(NSImage *)icon;
+(NSString *)IDString;

-(id)initWithSDR:(XTDTTSP *)sdr;

-(BOOL)start;
-(BOOL)stop;

-(void)setFrequency: (int)_frequency forReceiver: (int)_receiver;
-(int)getFrequency: (int)_receiver;

@end