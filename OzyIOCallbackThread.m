//
//  OzyIOCallbackThread.m
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

#import "OzyIOCallbackThread.h"

#import <IOKit/IOKitLib.h>
#import <IOKit/IOCFPlugIn.h>
#import <IOKit/usb/IOUSBLib.h>

#import "OzyInterface.h"

@implementation OzyIOCallbackThread

@synthesize runLoop;
@synthesize interface;

-(id) init {
	self = [super init];
	
	if(self) {
		[self setName:@"OzyIOCallbackThread"];
	}
	
	return self;
}

-(void) main {
	IONotificationPortRef notification_port;
	CFRunLoopSourceRef notification_source;
	mach_port_t master_port;
	CFMutableDictionaryRef matchingDict;
	io_iterator_t matchedIterator;
	
	kern_return_t kr;
	
	SInt32 ozyVendorId = 0xfffe;
	SInt32 ozyDeviceId = 0x0007;
	
	struct thread_time_constraint_policy ttcpolicy;
	mach_timebase_info_data_t tTBI;
	double mult;
	
	runLoop = [NSRunLoop currentRunLoop];
	
	[[interface ozyReady] lockWhenCondition:0];
	
	kr = IOMasterPort(MACH_PORT_NULL, &master_port);
	if(kr != kIOReturnSuccess) {
		NSLog(@"OzyIOCallbackThread: Couldn't get master port\n");
		return;
	}
	
	matchingDict = IOServiceMatching(kIOUSBDeviceClassName);
	if(!matchingDict) {
		NSLog(@"[OzyInterface initDevice]: Couldn't create a USB matching dictionary\n");
		return;
	}
	
	CFDictionarySetValue(matchingDict, CFSTR(kUSBVendorName), CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &ozyVendorId));
	CFDictionarySetValue(matchingDict, CFSTR(kUSBProductName), CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &ozyDeviceId));
	
	matchingDict = (CFMutableDictionaryRef) CFRetain(matchingDict);
	matchingDict = (CFMutableDictionaryRef) CFRetain(matchingDict);
	
	//  Set this callback thread to realtime status
	mach_timebase_info(&tTBI);
	mult = ((double)tTBI.denom / (double)tTBI.numer) * 1000000;
	
	ttcpolicy.period = 12 * mult;
	ttcpolicy.computation = 2 * mult;
	ttcpolicy.constraint = 24 * mult;
	ttcpolicy.preemptible = 0;
	
	if((thread_policy_set(mach_thread_self(), THREAD_TIME_CONSTRAINT_POLICY, (thread_policy_t) &ttcpolicy, THREAD_TIME_CONSTRAINT_POLICY_COUNT)) != KERN_SUCCESS) {
		NSLog(@"[OzyIOCallbackThread main]:  Failed to set callback to realtime\n");
	} 
	
	notification_port = IONotificationPortCreate(master_port);
	notification_source = IONotificationPortGetRunLoopSource(notification_port);
	CFRunLoopAddSource(CFRunLoopGetCurrent(), notification_source, kCFRunLoopDefaultMode);
	
	kr = IOServiceAddMatchingNotification(notification_port, 
										  kIOFirstMatchNotification, 
										  matchingDict, 
										  matched_callback, 
										  self, 
										  &matchedIterator);
	if(kr != kIOReturnSuccess) {
		NSLog(@"[OzyIOCallbackThread main]: Couldn't register port for match\n");
	}
	

	matched_callback(self, matchedIterator);

	
	kr = IOServiceAddMatchingNotification(notification_port, 
										  kIOTerminatedNotification, 
										  matchingDict,
										  removed_callback,
										  self, 
										  &matchedIterator);
	if(kr != kIOReturnSuccess) {
		NSLog(@"[OzyIOCallbackThread main]: Couldn't register port for match\n");
	}
	
	removed_callback(self, matchedIterator);
	
	CFRunLoopRun();
}

-(void)matchedCallback: (io_service_t) ozyDevice {
	//[[interface ozyReady] lockWhenCondition: 0];
	if(ozyDevice == 0) return;
	
	[interface openDevice: ozyDevice];
	
	if(FXLoaded == NO) {
		FXLoaded = YES;
		[interface resetCPU: 1];
		[interface loadFXFirmwareFromFile: [[NSBundle mainBundle] pathForResource:@"ozyfw-sdr1k" ofType:@"hex"]];
		[interface resetCPU: 0];
		return;
	}
	if(FPGALoaded == NO) {
		NSMutableData *i2CData = [NSMutableData dataWithLength:2];
		unsigned char *i2CDataBytes = [i2CData mutableBytes];
		
		FPGALoaded = YES;
		[interface loadFPGAFromFile: [[NSBundle	mainBundle] pathForResource:@"Ozy_Janus" ofType:@"rbf"]];
	
		//  Set up Penelope:  This should probably be configurable somewhere in
		// the properties.
		
		//  Reset Chip
		i2CDataBytes[0] = 0x1E;
		i2CDataBytes[1] = 0x00;
		[interface writeI2CAtAddress:0x1B withData:i2CData];
		
		//  Set digial interface active
		i2CDataBytes[0] = 0x12;
		i2CDataBytes[1] = 0x01;
		[interface writeI2CAtAddress:0x1B withData:i2CData];
		
		//  DAC on -- Mic input and 20dB Boost
		i2CDataBytes[0] = 0x08;
		i2CDataBytes[1] = 0x15;
		[interface writeI2CAtAddress:0x1B withData:i2CData];
		
		//  DAC on -- Mic input and no boost
		i2CDataBytes[0] = 0x08;
		i2CDataBytes[1] = 0x14;
		[interface writeI2CAtAddress:0x1B withData:i2CData];		
		
		//  All chip power on
		i2CDataBytes[0] = 0x0C;
		i2CDataBytes[1] = 0x00;
		[interface writeI2CAtAddress:0x1B withData:i2CData];
		
		//  Slave, 16 bit, I2S
		i2CDataBytes[0] = 0x0E;
		i2CDataBytes[1] = 0x02;
		[interface writeI2CAtAddress:0x1B withData:i2CData];
		
		//  48k Normal Mode
		i2CDataBytes[0] = 0x10;
		i2CDataBytes[1] = 0x00;
		[interface writeI2CAtAddress:0x1B withData:i2CData];
		
		//  Turn DAC mute off
		i2CDataBytes[0] = 0x0A;
		i2CDataBytes[1] = 0x00;
		[interface writeI2CAtAddress:0x1B withData:i2CData];
	}
	[interface initInterface];
	[interface performSelectorOnMainThread:@selector(beginReadChains) withObject:nil waitUntilDone:NO];

	[[interface ozyReady] unlockWithCondition: 1];
}

-(void)removedCallback: (io_service_t) ozyDevice {
	if(ozyDevice == 0) return;
	
	if(FPGALoaded == YES && FXLoaded == YES) {
		[interface closeDevice];
		FPGALoaded = NO;
		FXLoaded = NO;
	}
	// [[interface ozyReady] lockWhenCondition: 1];
}
@end

void matched_callback(void *inputData, io_iterator_t iterator) {
	OzyIOCallbackThread *self = (OzyIOCallbackThread *)inputData;
	
	[self matchedCallback: IOIteratorNext(iterator)];
	while(IOIteratorNext(iterator));
}

void removed_callback(void *inputData, io_iterator_t iterator) {
	OzyIOCallbackThread *self = (OzyIOCallbackThread *)inputData;
	
	[self removedCallback: IOIteratorNext(iterator)];
	while(IOIteratorNext(iterator));
}