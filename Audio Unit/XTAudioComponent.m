//
//  XTAudioComponent.m
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

// $Id$

#import "XTAudioComponent.h"


@implementation XTAudioComponent

-(id)initWithComponent:(AudioComponent)component {
	self = [super init];
	
	if(self) {
		theComponent = component;
		AudioComponentGetDescription(theComponent, &theComponentDescription);
		AudioComponentGetVersion(theComponent, &version);
	}
	
	return self;
}

-(NSString *)name {
	NSString *name = nil;
	
	AudioComponentCopyName(theComponent, (CFStringRef *) &name);
	return name;
}

-(UInt32)version {
	return version;
}

-(NSString *)versionString {	
	UInt32 dot = version & 0x000000FF;
	UInt32 minor = (version & 0x0000FF00) >> 2;
	UInt32 major = (version & 0xFFFF0000) >> 4;
	
	return [NSString stringWithFormat:@"%x.%x.%x", major, minor, dot];
}

-(AudioComponentDescription *)description {
	return &theComponentDescription;
}

+(XTAudioComponent *)audioComponentWithComponent:(AudioComponent)component {
	return [[XTAudioComponent alloc] initWithComponent:component];
}

+(NSArray *)getInstalledComponentsOfType:(OSType)type andManufacturer:(OSType)manufacturer {
	AudioComponent currentComponent;
	AudioComponentDescription componentSearchDescription;
	
	componentSearchDescription.componentType = type;
	componentSearchDescription.componentSubType = 0;
	componentSearchDescription.componentManufacturer = manufacturer;
	componentSearchDescription.componentFlags = 0;
	componentSearchDescription.componentFlagsMask = 0;
	
	NSMutableArray *componentArray = [NSMutableArray arrayWithCapacity:AudioComponentCount(&componentSearchDescription)];
	
	while((currentComponent = AudioComponentFindNext(currentComponent, &componentSearchDescription)) != 0) {				
		[componentArray addObject:[XTAudioComponent audioComponentWithComponent:currentComponent]];		
	}	
	
	return [NSArray arrayWithArray:componentArray];
}

+(NSArray *)getInstalledComponentsOfType:(OSType)type {
	return [XTAudioComponent getInstalledComponentsOfType:type andManufacturer:0];
}

+(NSArray *)getInstalledComponents {
	return [XTAudioComponent getInstalledComponentsOfType:0 andManufacturer: 0];
}

@end
