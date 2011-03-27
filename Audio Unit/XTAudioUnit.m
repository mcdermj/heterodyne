//
//  XTAudioUnit.m
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

#import "XTAudioUnit.h"

#import <AudioUnit/AUCocoaUIView.h>

@implementation XTAudioUnit

+ (BOOL) pluginClassIsValid:(Class)pluginClass 
{
	if([pluginClass conformsToProtocol: @protocol(AUCocoaUIBase)]) {
		if([pluginClass instancesRespondToSelector: @selector(interfaceVersion)] &&
		   [pluginClass instancesRespondToSelector: @selector(uiViewForAudioUnit:withSize:)]) {
			return YES;
		}
	}
    return NO;
}

+(AudioDeviceID)findSoundflowerWithChannels:(int)channels {
	NSString *kSoundFlower = @"com_cycling74_driver_SoundflowerDevice:Soundflower";
	AudioObjectPropertyAddress theAddress;
	UInt32 devicesSize;
	OSStatus error;
	
	theAddress.mElement = kAudioObjectPropertyElementMaster;
	theAddress.mScope = kAudioObjectPropertyScopeGlobal;
	theAddress.mSelector = kAudioHardwarePropertyDevices;
	
	error = AudioObjectGetPropertyDataSize(kAudioObjectSystemObject, &theAddress, 0, NULL, &devicesSize);
	if (error != noErr) 
		NSLog(@"%@:%s Error Getting device property size: %s\n", [self class], (char *) _cmd, GetMacOSStatusErrorString(error));
	
	int numDevices = devicesSize / sizeof(AudioDeviceID);
	
	AudioDeviceID *devices = (AudioDeviceID *) malloc(devicesSize);
	error = AudioObjectGetPropertyData(kAudioObjectSystemObject, &theAddress, 0, NULL, &devicesSize, devices);
	if (error != noErr) 
		NSLog(@"%@:%s Error Getting device property: %s\n", [self class], (char *) _cmd, GetMacOSStatusErrorString(error));
	
	
	for(int i = 0; i < numDevices; ++i) {
		NSString *name;
		NSString *modelUID;
		UInt32 paramSize;
		AudioBufferList *bufferList;
		
		paramSize = sizeof(CFStringRef);
		
		theAddress.mSelector = kAudioDevicePropertyModelUID;
		error = AudioObjectGetPropertyData(devices[i], &theAddress, 0, NULL, &paramSize, &modelUID);
		if (error != noErr) 
			NSLog(@"%@:%s Error Getting device UID property: %s\n", [self class], (char *) _cmd, GetMacOSStatusErrorString(error));
		
		if([modelUID isEqualToString:kSoundFlower] == NO)
			continue;
		
		theAddress.mSelector = kAudioObjectPropertyName;
		error = AudioObjectGetPropertyData(devices[i], &theAddress, 0, NULL, &paramSize, &name);
		if (error != noErr) 
			NSLog(@"%@:%s Error Getting device name property: %s\n", [self class], (char *) _cmd, GetMacOSStatusErrorString(error));		
		
		//  Enumerate the output streams
		theAddress.mSelector = kAudioDevicePropertyStreamConfiguration;
		theAddress.mScope = kAudioDevicePropertyScopeOutput;
		error = AudioObjectGetPropertyDataSize(devices[i], &theAddress, 0, NULL, &paramSize);
		if (error != noErr) 
			NSLog(@"%@:%s Error Getting stream property size: %s\n", [self class], (char *) _cmd, GetMacOSStatusErrorString(error));		
		
		bufferList = (AudioBufferList *)malloc(paramSize);
		
		error = AudioObjectGetPropertyData(devices[i], &theAddress, 0, NULL, &paramSize, bufferList);
		if (error != noErr) 
			NSLog(@"%@:%s Error Getting stream name property: %s\n", [self class], (char *) _cmd, GetMacOSStatusErrorString(error));		
		
		if(bufferList->mBuffers[0].mNumberChannels == channels) {
			free(bufferList);
			AudioDeviceID soundflower = devices[i];
			free(devices);
			NSLog(@"Found SoundFlower: %@\n", name);
			return soundflower;
		}
		
		free(bufferList);
	}
	
	free(devices);
	return -1;
}

+(id)audioUnitWithType:(OSType)type subType:(OSType)subType andManufacturer:(OSType)manufacturer {
	return [[XTAudioUnit alloc] initWithType:type subType:subType andManufacturer:manufacturer];
}

-(id)initWithType:(OSType)type subType:(OSType)subType andManufacturer:(OSType)manufacturer {
	OSStatus error;

	self = [super init];
	
	if(self) {
		AudioComponentDescription componentDescription;
		AudioComponent component;
		
		componentDescription.componentType = type;
		componentDescription.componentSubType = subType;
		componentDescription.componentManufacturer = manufacturer;
		componentDescription.componentFlags = 0;
		componentDescription.componentFlagsMask = 0;

		component = AudioComponentFindNext(NULL, &componentDescription);
		error = AudioComponentInstanceNew(component, &theUnit);
		if(error != noErr)
			NSLog(@"%@:%s Error creating audio unit: %s\n", [self class], (char *) _cmd, GetMacOSStatusErrorString(error));
	}
	
	return self;
}

-(void)dispose {
	NSLog(@"Diposing of audio unit\n");
	AudioComponentInstanceDispose(theUnit);
}

-(void)initialize {
	OSStatus error;
	
	error = AudioUnitInitialize(theUnit);
	if(error != noErr)
		NSLog(@"[%@ %s] Error initializing audio unit: %s\n", [self class], (char *) _cmd, GetMacOSStatusErrorString(error));

}

-(void)uninitialize {
	OSStatus error;
	
	error = AudioUnitUninitialize(theUnit);
	if(error != noErr)
		NSLog(@"[%@ %s] Error uninitializing audio unit: %s\n", [self class], (char *) _cmd, GetMacOSStatusErrorString(error));
	
}


-(AudioUnit *) unit {
	return &theUnit;
}

-(OSStatus)setProperty:(AudioUnitPropertyID)property withScope:(AudioUnitScope)scope andData:(NSData *)data {
	return AudioUnitSetProperty(theUnit, property, scope, 0, [data bytes], [data length]);
}

-(OSStatus)setInputFormat:(AudioStreamBasicDescription *)format {
	return [self setProperty:kAudioUnitProperty_StreamFormat withScope:kAudioUnitScope_Input andData:[NSData dataWithBytes:format length:sizeof(AudioStreamBasicDescription)]];
}

-(OSStatus)setMaxFramesPerSlice:(UInt32)frames {
	return [self setProperty:kAudioUnitProperty_MaximumFramesPerSlice withScope:kAudioUnitScope_Global andData:[NSData dataWithBytes:&frames length:sizeof(frames)]];
}

-(OSStatus)setCallback:(AURenderCallbackStruct *)callback {
	return [self setProperty:kAudioUnitProperty_SetRenderCallback withScope:kAudioUnitScope_Input andData:[NSData dataWithBytes:callback length:sizeof(AURenderCallbackStruct)]];
}

-(NSView *)cocoaView {
	NSView *theView = nil;
	UInt32 dataSize = 0;
	Boolean isWritable = 0;
	AudioUnitCocoaViewInfo *cocoaViewInfo;
	
	OSStatus error = AudioUnitGetPropertyInfo(theUnit, kAudioUnitProperty_CocoaUI, kAudioUnitScope_Global, 0, &dataSize, &isWritable);
	if(error != noErr) {
		NSLog(@"%@:%s No Cocoa View Exists: %s\n", [self class], (char *) _cmd, GetMacOSStatusErrorString(error));
		return nil;
	}
	
	cocoaViewInfo = (AudioUnitCocoaViewInfo *)malloc(dataSize);
	AudioUnitGetProperty(theUnit, kAudioUnitProperty_CocoaUI, kAudioUnitScope_Global, 0, cocoaViewInfo, &dataSize);
	
	unsigned numberOfClasses = (dataSize - sizeof(CFURLRef)) / sizeof (CFStringRef);
	NSURL *cocoaViewBundlePath = (NSURL *)cocoaViewInfo->mCocoaAUViewBundleLocation;
	NSBundle *cocoaViewBundle = [NSBundle bundleWithPath:[cocoaViewBundlePath path]];
	NSString *factoryClassName = (NSString *)cocoaViewInfo->mCocoaAUViewClass[0];
	Class factoryClass = [cocoaViewBundle classNamed:factoryClassName];
	
	if([XTAudioUnit pluginClassIsValid:factoryClass]) {
		id factoryInstance = [[factoryClass alloc] init];
		theView = [factoryInstance uiViewForAudioUnit:theUnit withSize:NSMakeSize(400, 300)];
	}
	
	if(cocoaViewInfo) {
		int i;
		for(i = 0; i < numberOfClasses; ++i) {
			CFRelease(cocoaViewInfo->mCocoaAUViewClass[i]);
		}
		
		free(cocoaViewInfo);
	}
	
	return theView;
}

-(NSWindow *)cocoaWindow {
	NSWindow *theWindow;

	NSView *theView = [self cocoaView];
	if(theView == nil) {
		NSLog(@"%@:%s Can't get cocoa view.\n", [self class], (char *) _cmd);
		return nil;
	}
	
	theWindow = [[NSWindow alloc] initWithContentRect:NSMakeRect(100, 400, [theView frame].size.width, [theView frame].size.height) styleMask:NSTitledWindowMask | NSClosableWindowMask | NSMiniaturizableWindowMask | NSResizableWindowMask backing:NSBackingStoreBuffered defer:NO];
	[theWindow setContentView: theView];
	[theWindow setIsVisible: YES];
	
	return theWindow;
}

-(void)makeSoundflowerWithChannels:(int)channels {
	OSStatus error;
	
	AudioDeviceID soundflowerDevice = [XTAudioUnit findSoundflowerWithChannels:channels];
	
	error = [self setProperty:kAudioOutputUnitProperty_CurrentDevice withScope:kAudioUnitScope_Global andData:[NSData dataWithBytes:&soundflowerDevice length:sizeof(AudioDeviceID)]];
	if (error != noErr) 
		NSLog(@"%@:%s Error setting output device: %s\n", [self class], (char *) _cmd, GetMacOSStatusErrorString(error));		
	
	return;
}

-(void)makeDefaultOutput {
	OSStatus error;
	
	AudioObjectPropertyAddress theAddress;
	AudioDeviceID defaultDevice;
	UInt32 defaultDeviceSize;
	
	theAddress.mElement = kAudioObjectPropertyElementMaster;
	theAddress.mScope = kAudioObjectPropertyScopeGlobal;
	theAddress.mSelector = kAudioHardwarePropertyDefaultOutputDevice;
	
	error = AudioObjectGetPropertyData(kAudioObjectSystemObject, &theAddress, 0, NULL, &defaultDeviceSize, &defaultDevice);
	if (error != noErr) 
		NSLog(@"%@:%s Error Getting device property: %s\n", [self class], (char *) _cmd, GetMacOSStatusErrorString(error));	
		
	error = [self setProperty:kAudioOutputUnitProperty_CurrentDevice withScope:kAudioUnitScope_Global andData:[NSData dataWithBytes:&defaultDevice length:sizeof(AudioDeviceID)]];
	if (error != noErr) 
		NSLog(@"%@:%s Error setting output device: %s\n", [self class], (char *) _cmd, GetMacOSStatusErrorString(error));		
	
	return;	
}

@end
