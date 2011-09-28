//
//  NNHOzyDriver.m
//  Heterodyne
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

// $Id:$

#import "NNHOzyDriver.h"

#import "XTDTTSP.h"
#import "OzyInputBuffers.h"
#import "OzyRingBuffer.h"

#include <mach/mach_time.h>
#include <mach/thread_policy.h>
#include <mach/mach_init.h>

@implementation OzyCallbackData
@synthesize interface;
@synthesize data;

-(id)initWithData:(NSMutableData *)newData andInterface:(NNHOzyDriver *)newInterface {
	self = [super init];
	
	if(self) {
		data = newData;
		interface = newInterface;
	}
	
	return self;
}

+(id)ozyCallbackData:(NSMutableData *)data andInterface:(NNHOzyDriver *)interface {
	return [[OzyCallbackData alloc] initWithData:data andInterface:interface];
}
@end

@implementation NNHOzyDriver

@synthesize sdr;
@synthesize sampleRate;
@synthesize ozyVersion;
@synthesize penelopeVersion;
@synthesize mercuryVersion;

@synthesize tenMHzSource;
@synthesize oneTwentyTwoMHzSource;
@synthesize penelopePresent;
@synthesize mercuryPresent;
@synthesize micSource;
@synthesize classE;
@synthesize alexAttenuator;
@synthesize preamp;
@synthesize dither;
@synthesize random;
@synthesize alexAntenna;
@synthesize alexRxOut;
@synthesize alexTxRelay;
@synthesize duplex;
@synthesize transmitterFrequency;
@synthesize driveLevel;
@synthesize micBoost;
@synthesize callbacks;
@synthesize fx2Version;


+(NSString *)name {
	return @"Ozy Driver";
}

+(float)version {
	return 1.0;
}

+(NSString *)versionString {
	return [NSString stringWithFormat:@"%0.1f", [NNHOzyDriver version]];
}

+(NSImage *)icon {
	NSBundle *myBundle = [NSBundle bundleForClass:[self class]];
	
	return [[NSImage alloc] initWithContentsOfFile:[myBundle pathForResource:[myBundle objectForInfoDictionaryKey:@"CFBundleIconFile"] ofType:@"icns"]];
}

+(NSString *)IDString {
	return [NSString stringWithFormat:@"%@ v%0.1f", [NNHOzyDriver name], [NNHOzyDriver version]];
}

-(void)loadParams {
	self.sampleRate = [[NSUserDefaults standardUserDefaults] integerForKey:@"OzyDriver.sampleRate"];
	dither = [[NSUserDefaults standardUserDefaults] boolForKey:@"OzyDriver.dither"];
	random = [[NSUserDefaults standardUserDefaults] boolForKey:@"OzyDriver.random"];
	tenMHzSource = [[NSUserDefaults standardUserDefaults] integerForKey:@"OzyDriver.tenMHzSource"];
	oneTwentyTwoMHzSource = [[NSUserDefaults standardUserDefaults] integerForKey:@"OzyDriver.oneTwentyTwoMHzSource"];
	mercuryPresent = [[NSUserDefaults standardUserDefaults] boolForKey:@"OzyDriver.mercuryPresent"];
	penelopePresent = [[NSUserDefaults standardUserDefaults] boolForKey:@"OzyDriver.penelopePresent"];
	micGain = [[NSUserDefaults standardUserDefaults] floatForKey:@"OzyDriver.micGain"];
	txGain = [[NSUserDefaults standardUserDefaults] floatForKey:@"OzyDriver.txGain"];
	
	openCollectors = 0x00;
	int i = 1;
	for (i = 1; i < 8; ++i) {
		NSString *collectorName = [NSString stringWithFormat:@"OzyDriver.oc%d", i];
		if([[NSUserDefaults standardUserDefaults] boolForKey:collectorName] == YES) {
			openCollectors |= (UInt8) (0x01 << i);
		}
	}
}

-(id)initWithSDR:(XTDTTSP *)newSdr {
	self = [super init];
	if(self) {
		sdr = newSdr;
		
		running = NO;
		
		mox = NO;
		preamp = NO;
		alexRxOut = NO;
		duplex = NO;
		classE = NO;
		
		micSource = PENELOPE;
		alexAttenuator = 0;
		alexAntenna = 0;
		alexTxRelay = 0;
		driveLevel = 0;
		micBoost = 0;
		
		openCollectors = 0;
		
		callbacks = [NSMutableArray arrayWithCapacity:5];
		
		ep6Buffers = [[OzyInputBuffers alloc] initWithSize:OZY_BUFFER_SIZE quantity:32];
		outputBuffer = [[OzyRingBuffer alloc] initWithEntries:(64 * OZY_BUFFER_DATA_SIZE)];
		
		for(int i = 0; i < OZY_PACKETS_PER_INPUT_BUFFER; ++i) {
			outputPacket[i].magic[0] = SYNC;
			outputPacket[i].magic[1] = SYNC;
			outputPacket[i].magic[2] = SYNC;
		}
		
		NSDictionary *driverDefaults = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle bundleForClass:[self class]] pathForResource:@"OzyDefaults" ofType:@"plist"]];
		[[NSUserDefaults standardUserDefaults] registerDefaults:driverDefaults];
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector: @selector(loadParams) name: NSUserDefaultsDidChangeNotification object: nil];
		[self loadParams];

	}
	
	return self;
}

-(void)closeDevice {
	if(ozyUSBDevice == NULL) 
		return;
	
	(*ozyUSBDevice)->USBDeviceClose(ozyUSBDevice);
	(*ozyUSBDevice)->Release(ozyUSBDevice);
	ozyUSBDevice = NULL;
}

-(BOOL)start {
	running = YES;
	[NSThread detachNewThreadSelector:@selector(ioCallbackThread) toTarget:self withObject:nil];
	[NSThread detachNewThreadSelector:@selector(ep6ProcessingThread) toTarget:self withObject:nil];
	return YES;
}

-(BOOL)stop {
	[self closeDevice];
	running = NO;
	return YES;
}

-(void)setFrequency: (int)frequency forReceiver:(int)receiver {
	receiverFrequency[receiver] = frequency;
    [[NSNotificationCenter defaultCenter] postNotificationName:@"XTPassbandCenterChanged" object:self];
}

-(int)getFrequency:(int)receiver {
	return receiverFrequency[receiver];
}

-(void)setSampleRate: (int) _sampleRate {
	NSLog(@"Sample rate set to: %d\n", _sampleRate);
	
	if(sampleRate == _sampleRate) {
		return;
	}
	
	switch(_sampleRate){
		case 48000:
			outputSampleIncrement = 1;
			sampleRate = 48000;
			break;
		case 96000:
			outputSampleIncrement = 2;
			sampleRate = 96000;
			break;
		case 192000:
			outputSampleIncrement = 4;
			sampleRate = 192000;
			break;
		default:
			outputSampleIncrement = 1;
			sampleRate = 48000;
			break;
	}
	
	[[NSNotificationCenter defaultCenter] postNotificationName:@"XTSampleRateChanged" object:self];
}

-(NSView *)configWindow {
	if(configWindow == nil) {
		if(![NSBundle loadNibNamed:@"NNHOzyDriver" owner:self] ) {
			NSLog(@"[%@ %s] Could not load config view bundle.\n", [self class], (char *) _cmd);
			
		}
	}
	
	if(configWindow == nil) {
		NSLog(@"[%@ %s] Config window isn't there!\n", [self class], (char *) _cmd);
	}
	
	return configWindow;
}

-(void)loadFPGAFromFile: (NSString *)firmwareFileName {
	NSData *firmwareFileData = [NSData dataWithContentsOfFile:firmwareFileName];
	IOUSBDevRequest writeRequest;
	kern_return_t kr;
	NSRange packetRange;
	int bytesTransferred = 0;
	
	if(firmwareFileData == nil) {
		NSLog(@"[%@ %s]: Couldn't open FPGA file: %@\n", [self class], (char *) _cmd, firmwareFileName);
		return;
	}
	
	writeRequest.bmRequestType = VENDOR_REQ_TYPE_OUT;
	writeRequest.bRequest = VENDOR_REQ_FPGA_LOAD;
	writeRequest.wValue = 0;
	writeRequest.wIndex = FIRMWARE_LOAD_BEGIN;
	writeRequest.pData = NULL;
	writeRequest.wLength = 0;
	
	kr = (*ozyUSBDevice)->DeviceRequest(ozyUSBDevice, &writeRequest);
	if( kr != kIOReturnSuccess ) {
		NSLog(@"[%@ %s]: Couldn't write load begin to Ozy (%02x)\n", [self class], (char *) _cmd, kr);
		return;
	}
	
	for(packetRange = NSMakeRange(0, MAX_EP0_PACKET_SIZE); packetRange.location < firmwareFileData.length; packetRange.location += packetRange.length) {
		if(packetRange.location + packetRange.length > firmwareFileData.length) {
			packetRange.length = firmwareFileData.length - packetRange.location;
		}
		
		NSData *packetData = [firmwareFileData subdataWithRange:packetRange];
		
		writeRequest.wIndex = FIRMWARE_LOAD_XFER;
		writeRequest.pData = (void *) packetData.bytes;
		writeRequest.wLength = packetData.length;
		
		kr = (*ozyUSBDevice)->DeviceRequest(ozyUSBDevice, &writeRequest);
		if( kr != kIOReturnSuccess ) {
			NSLog(@"[%@ %s]: Couldn't write load xfer to Ozy (%02x)\n", [self class], (char *) _cmd, kr);
			return;
		}
		bytesTransferred += writeRequest.wLenDone;
	}
	
	writeRequest.wIndex = FIRMWARE_LOAD_END;
	writeRequest.pData = NULL;
	writeRequest.wLength = 0;
	
	kr = (*ozyUSBDevice)->DeviceRequest(ozyUSBDevice, &writeRequest);
	if( kr != kIOReturnSuccess ) {
		NSLog(@"[%@ %s]: Couldn't write load end to Ozy (%02x)\n", [self class], (char *) _cmd, kr);
		return;
	}
	NSLog(@"[%@ %s]: Transferred %d bytes of FPGA Firmware\n", [self class], (char *) _cmd, bytesTransferred);
}

-(void)writeRAMAtAddress: (int)startAddress andData:(NSData *) theData {
	NSRange packetRange;
	IOUSBDevRequest writeRequest;
	NSData *packetData;
	kern_return_t kr;
	
	writeRequest.bmRequestType = 0x40;
	writeRequest.bRequest = 0xA0;
	writeRequest.wIndex = 0;
	
	for(packetRange = NSMakeRange(0, MAX_EP0_PACKET_SIZE); packetRange.location < theData.length; packetRange.location += packetRange.length) {
		if(packetRange.location + packetRange.length > theData.length) {
			packetRange.length = theData.length - packetRange.location;
		}
		
		packetData = [theData subdataWithRange:packetRange];
		
		writeRequest.wValue = startAddress + packetRange.location;
		writeRequest.pData = (void *) packetData.bytes;
		writeRequest.wLength = packetData.length;
		
		kr = (*ozyUSBDevice)->DeviceRequest(ozyUSBDevice, &writeRequest);
		if(kr != kIOReturnSuccess) {
			NSLog(@"[%@ %s]: Couldn't perform write (%08x)\n", [self class], (char *) _cmd, kr);
			return;
		}
	}
}

-(void)resetCPU: (BOOL)reset {
	char buffer;
	
	buffer = (reset == TRUE ? 1 : 0);
	
	[self writeRAMAtAddress: 0xE600 andData:[NSData dataWithBytes:&buffer length:1]];
}

-(void)writeI2CAtAddress: (int) startAddress withData: (NSData *) theData {
	IOUSBDevRequest i2CRequest;
	kern_return_t kr;
	
	i2CRequest.bmRequestType = VENDOR_REQ_TYPE_OUT;
	i2CRequest.bRequest = VENDOR_REQ_I2C_WRITE;
	i2CRequest.wIndex = 0x00;
	i2CRequest.wValue = startAddress;
	i2CRequest.pData = (void *) [theData bytes];
	i2CRequest.wLength = [theData length];
	
	kr = (*ozyUSBDevice)->DeviceRequest(ozyUSBDevice, &i2CRequest);
	if(kr != kIOReturnSuccess) {
		NSLog(@"[%@ %s]: Couldn't perform write (%08x)\n", [self class], (char *) _cmd, kr);
		return;
	}
}

+(int)intForHexString: (NSString *)theHexString {
	return strtol([theHexString cStringUsingEncoding: NSASCIIStringEncoding], NULL, 16);
}

-(void)loadFXFirmwareFromFile: (NSString *)fileName {
	int length, addr, type, lines = 0;
	
	unsigned char expectedChecksum, actualChecksum;
	
	NSString *fileString = [NSString stringWithContentsOfFile:fileName encoding: NSASCIIStringEncoding error: NULL];
	if(fileString == nil) {
		NSLog(@"[%@ %s]: Couldn't read file %@\n", [self class], (char *) _cmd, fileName);
		return;
	}
	
	NSArray *fileLines = [fileString componentsSeparatedByString:@"\r\n"];
	
	for(NSString *fileLine in fileLines) {
		NSRange currentRange;
		NSMutableData *firmwareBuffer = [NSMutableData dataWithLength:0];
		
		if([fileLine length] < 1) continue;
		
		if([fileLine characterAtIndex:0] != ':') {
			NSLog(@"[%@ %s]: Bad record\n", [self class], (char *) _cmd);
			return;
		}
		
		length = [NNHOzyDriver intForHexString: [fileLine substringWithRange: NSMakeRange(1, 2)]];
		addr = [NNHOzyDriver intForHexString: [fileLine substringWithRange: NSMakeRange(3, 4)]];
		type = [NNHOzyDriver intForHexString: [fileLine substringWithRange: NSMakeRange(7, 2)]];
		
		switch(type) {
			case 0:
				actualChecksum = (unsigned char)(length + (addr & 0xFF) + (addr >> 8 + type));
				for( currentRange = NSMakeRange(9, 2); currentRange.location < (length * 2) + 9; currentRange.location += currentRange.length) {
					int value = [NNHOzyDriver intForHexString: [fileLine substringWithRange: currentRange]];
					if( value < 0 ) {
						NSLog(@"[%@ %s]: Bad record data: %d\n", [self class], (char *) _cmd, value);
					}
					[firmwareBuffer appendBytes:&value length:1];
					actualChecksum += value;
				}
				
				expectedChecksum = [NNHOzyDriver intForHexString: [fileLine	substringWithRange:currentRange]];
				if(expectedChecksum < 0) {
					NSLog(@"[%@ %s]: Bad checksum data\n", [self class], (char *) _cmd);
				}
				
				if(((expectedChecksum + actualChecksum) & 0xFF) != 0 ) {
					NSLog(@"[%@ %s]: Bad checksum\n", [self class], (char *) _cmd);
				}
				
				[self writeRAMAtAddress:addr andData:firmwareBuffer];
				break;
			case 1:
				// EOF
				break;
				
			default:
				NSLog(@"[%@ %s]: Invalid record type %d\n", [self class], (char *) _cmd, type);
				return;
		}
		++lines;
	}
	NSLog(@"[%@ %s]: Wrote %d lines to Ozy\n", [self class], (char *) _cmd, lines);
}


-(kern_return_t)openDevice: (io_service_t) ozyDevice {
	IOCFPlugInInterface **ozyPlugIn = NULL;
	kern_return_t kr;
	HRESULT hr;
	SInt32 score;
	
	
	if(IOCreatePlugInInterfaceForService(ozyDevice, kIOUSBDeviceUserClientTypeID, kIOCFPlugInInterfaceID, &ozyPlugIn, &score) != KERN_SUCCESS) {
		NSLog(@"[%@ %s]: Couldn't get an Ozy PlugIn interface\n", [self class], (char *) _cmd);
		return kr;
	}
	
	IOObjectRelease(ozyDevice);
	
	hr = (*ozyPlugIn)->QueryInterface(ozyPlugIn, CFUUIDGetUUIDBytes(kIOUSBDeviceInterfaceID), (LPVOID *)&ozyUSBDevice);
	(*ozyPlugIn)->Release(ozyPlugIn);
	
	if(hr || !ozyUSBDevice) {
		NSLog(@"[%@ %s]: Couldn't create an USB device interface (%08x)\n", [self class], (char *) _cmd, (int) hr);
		return kr;
	}
	
	kr = (*ozyUSBDevice)->USBDeviceOpenSeize(ozyUSBDevice);
	if(kr != kIOReturnSuccess) {
		NSLog(@"[%@ %s]: Unable to open device (%08x)\n", [self class], (char *) _cmd, kr);
		(*ozyUSBDevice)->USBDeviceClose(ozyUSBDevice);
		(*ozyUSBDevice)->Release(ozyUSBDevice);
		return kr;
	}
	
	return kIOReturnSuccess;
}

-(kern_return_t)initInterface {
	kern_return_t kr;
	HRESULT hr;
	
	IOUSBFindInterfaceRequest interfaceRequest;
	
	IOUSBConfigurationDescriptorPtr ozyConfigDescriptor = NULL;
	
	io_iterator_t ozyInterfaceIterator = 0;
	io_service_t ozyInterfaceDevice = 0;	
	
	IOCFPlugInInterface **ozyPlugIn = NULL;
	
	SInt32 score;
	
	CFRunLoopSourceRef runLoopSource;
	
	kr = (*ozyUSBDevice)->GetConfigurationDescriptorPtr(ozyUSBDevice, 0, &ozyConfigDescriptor);
	if(kr != kIOReturnSuccess) {
		NSLog(@"[%@ %s]: Unable to get configuration descriptor (%08x)\n", [self class], (char *) _cmd, kr);
		return kr;
	}
	
	kr = (*ozyUSBDevice)->SetConfiguration(ozyUSBDevice, ozyConfigDescriptor->bConfigurationValue);
	if(kr != kIOReturnSuccess) {
		NSLog(@"[%@ %s]: Unable to set configuration (%08x)\n", [self class], (char *) _cmd, kr);
		return kr;
	}
	
	interfaceRequest.bInterfaceClass = kIOUSBFindInterfaceDontCare;
	interfaceRequest.bInterfaceSubClass = kIOUSBFindInterfaceDontCare;
	interfaceRequest.bInterfaceProtocol = kIOUSBFindInterfaceDontCare;
	interfaceRequest.bAlternateSetting = kIOUSBFindInterfaceDontCare;
	
	kr = (*ozyUSBDevice)->CreateInterfaceIterator(ozyUSBDevice, &interfaceRequest, &ozyInterfaceIterator);
	if(kr != kIOReturnSuccess) {
		NSLog(@"[%@ %s]:  Unable to get Interface Iterator (%08x)\n", [self class], (char *) _cmd, kr);
		return kr;
	}
	
	ozyInterfaceDevice = IOIteratorNext(ozyInterfaceIterator);
	
	kr = IOCreatePlugInInterfaceForService(ozyInterfaceDevice, kIOUSBInterfaceUserClientTypeID, kIOCFPlugInInterfaceID, &ozyPlugIn, &score);
	if(kr != kIOReturnSuccess) {
		NSLog(@"[%@ %s]:  Could not get plugin for configuration (%08x)\n", [self class], (char *) _cmd, kr);
		return kr;
	}
	
	IOObjectRelease(ozyInterfaceDevice);
	
	hr = (*ozyPlugIn)->QueryInterface(ozyPlugIn, CFUUIDGetUUIDBytes(kIOUSBInterfaceInterfaceID), (LPVOID *) &ozyUSBInterface);
	(*ozyPlugIn)->Release(ozyPlugIn);
	if(hr || !ozyUSBInterface) {
		NSLog(@"[%@ %s]:  Could not create a device interface (%08x)\n", [self class], (char *) _cmd, hr);
		return kr;
	}
	
	kr = (*ozyUSBInterface)->USBInterfaceOpen(ozyUSBInterface);
	if(kr != kIOReturnSuccess) {
		NSLog(@"[%@ %s]:  Cold not open USB interface (%08x)\n", [self class], (char *) _cmd, kr);
		return kr;
	}
	
	//  Enumerate pipes and find endpoints
	UInt8 endPoints;
	kr = (*ozyUSBInterface)->GetNumEndpoints(ozyUSBInterface, &endPoints);
	if(kr != kIOReturnSuccess) {
		NSLog(@"[%@ %s]: Could not get the number of endpoints\n", [self class], (char *) _cmd);
		return kr;
	}
	
	UInt8 pipe;
	for(pipe = 0; pipe <= endPoints; ++pipe) {
		UInt8 direction, number, transferType, interval;
		UInt16 maxPacketSize;
		
		kr = (*ozyUSBInterface)->GetPipeProperties(ozyUSBInterface, 
												   pipe, &direction, 
												   &number, &transferType, 
												   &maxPacketSize, &interval);
		if(number == 2) {
			if(direction != kUSBOut) {
				NSLog(@"[%@ %s]: Found EP2 to be other than inbound\n", [self class], (char *) _cmd);
			}
			ep2Pipe = pipe;
			NSLog(@"[%@ %s]: Found EP2 at pipe %d\n", [self class], (char *) _cmd, pipe);
		}
		
		if(number == 6) {
			if(direction != kUSBIn) {
				NSLog(@"[%@ %s]: Found EP6 to be other than inbound.\n", [self class], (char *) _cmd);
			}
			ep6Pipe = pipe;
			NSLog(@"[%@ %s]: Found EP6 at pipe %d\n", [self class], (char *) _cmd, pipe);
		}
		
		if(number == 4) {
			if(direction != kUSBIn) {
				NSLog(@"[%@ %s]: Found EP4 to be other than inbound.\n", [self class], (char *) _cmd);
			}
			ep4Pipe = pipe;
			NSLog(@"[%@ %s]: Found EP4 at pipe %d\n", [self class], (char *) _cmd, pipe);
		}
		
	}
	
	kr = (*ozyUSBInterface)->CreateInterfaceAsyncEventSource(ozyUSBInterface, &runLoopSource);
	if(kr != kIOReturnSuccess) {
		NSLog(@"[%@ %s]:  Could not create an event source (%08x)\n", [self class], (char *) _cmd, kr);
		return kr;
	}
	
	CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopDefaultMode);
	
	return kIOReturnSuccess;
}

-(void)reEnumerate {
	IOReturn kr;
	
	kr = (*ozyUSBDevice)->USBDeviceReEnumerate(ozyUSBDevice, 0);
	if(kr != kIOReturnSuccess) {
		NSLog(@"[%@ %s]: Unable reenumerate device (%08x)\n", [self class], (char *) _cmd, kr);
		return;
	}
}

-(void)removedCallback: (io_service_t) ozyDevice {
	if(ozyDevice == 0) return;
	
	NSLog(@"[%@ %s]: Removing device\n", [self class], (char *) _cmd);
	
	if(FPGALoaded == YES && FXLoaded == YES) {
		[self closeDevice];
		FPGALoaded = NO;
		FXLoaded = NO;
	}
}

-(void)matchedCallback: (io_service_t) ozyDevice {
	if(ozyDevice == 0) return;
	
	[self openDevice: ozyDevice];
	
	if(FXLoaded == NO) {
		FXLoaded = YES;
		[self resetCPU: 1];
		[self loadFXFirmwareFromFile: [[NSBundle mainBundle] pathForResource:@"ozyfw-sdr1k" ofType:@"hex"]];
		[self resetCPU: 0];
		return;
	}
	if(FPGALoaded == NO) {
		NSMutableData *i2CData = [NSMutableData dataWithLength:2];
		unsigned char *i2CDataBytes = [i2CData mutableBytes];
		
		//  Get the FX2 Version
		IOUSBDevRequest ozyVersionRequest;
		kern_return_t kr;
		char buffer[9];
		
		if(ozyUSBDevice == NULL) {
			[self willChangeValueForKey:@"fx2Version"];
			fx2Version = @"NO DEVICE";
			[self didChangeValueForKey:@"fx2Version"];
		}
		
		ozyVersionRequest.bmRequestType = VRT_VENDOR_IN;
		ozyVersionRequest.bRequest = VRQ_SDR1K_CTL;
		ozyVersionRequest.wValue = SDR1KCTRL_READ_VERSION;
		ozyVersionRequest.wIndex = 0;
		ozyVersionRequest.pData = buffer;
		ozyVersionRequest.wLength = 8;
		
		kr = (*ozyUSBDevice)->DeviceRequest(ozyUSBDevice, &ozyVersionRequest);
		if(kr != kIOReturnSuccess) {
			NSLog(@"[%@ %s]:  Couldn't make control request (%08x)\n", [self class], (char *) _cmd, kr);
			[self willChangeValueForKey:@"fx2Version"];
			fx2Version = @"ERROR";
			[self didChangeValueForKey:@"fx2Version"];
		}
		
		buffer[8] = 0;
		
		[self willChangeValueForKey:@"fx2Version"];
		fx2Version = [NSString stringWithCString:buffer encoding:NSASCIIStringEncoding];
		[self didChangeValueForKey:@"fx2Version"];
		
		FPGALoaded = YES;
		[self loadFPGAFromFile: [[NSBundle	mainBundle] pathForResource:@"Ozy_Janus" ofType:@"rbf"]];
		
		//  Set up Penelope:  This should probably be configurable somewhere in
		// the properties.
		
		//  Reset Chip
		i2CDataBytes[0] = 0x1E;
		i2CDataBytes[1] = 0x00;
		[self writeI2CAtAddress:0x1B withData:i2CData];
		
		//  Set digial interface active
		i2CDataBytes[0] = 0x12;
		i2CDataBytes[1] = 0x01;
		[self writeI2CAtAddress:0x1B withData:i2CData];
		
		//  DAC on -- Mic input and 20dB Boost
		i2CDataBytes[0] = 0x08;
		i2CDataBytes[1] = 0x15;
		[self writeI2CAtAddress:0x1B withData:i2CData];
		
		//  DAC on -- Mic input and no boost
		i2CDataBytes[0] = 0x08;
		i2CDataBytes[1] = 0x14;
		[self writeI2CAtAddress:0x1B withData:i2CData];		
		
		//  All chip power on
		i2CDataBytes[0] = 0x0C;
		i2CDataBytes[1] = 0x00;
		[self writeI2CAtAddress:0x1B withData:i2CData];
		
		//  Slave, 16 bit, I2S
		i2CDataBytes[0] = 0x0E;
		i2CDataBytes[1] = 0x02;
		[self writeI2CAtAddress:0x1B withData:i2CData];
		
		//  48k Normal Mode
		i2CDataBytes[0] = 0x10;
		i2CDataBytes[1] = 0x00;
		[self writeI2CAtAddress:0x1B withData:i2CData];
		
		//  Turn DAC mute off
		i2CDataBytes[0] = 0x0A;
		i2CDataBytes[1] = 0x00;
		[self writeI2CAtAddress:0x1B withData:i2CData];
	}
	[self initInterface];
	[self performSelectorOnMainThread:@selector(beginReadChains) withObject:nil waitUntilDone:NO];	
}

-(void) ioCallbackThread {
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
	
	kr = IOMasterPort(MACH_PORT_NULL, &master_port);
	if(kr != kIOReturnSuccess) {
		NSLog(@"[%@ %s]: Couldn't get master port\n", [self class], (char *) _cmd);
		return;
	}
	
	matchingDict = IOServiceMatching(kIOUSBDeviceClassName);
	if(!matchingDict) {
		NSLog(@"[%@ %s]: Couldn't create a USB matching dictionary\n", [self class], (char *) _cmd);
		return;
	}
	
	CFDictionarySetValue(matchingDict, CFSTR(kUSBVendorName), CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &ozyVendorId));
	CFDictionarySetValue(matchingDict, CFSTR(kUSBProductName), CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &ozyDeviceId));
	
	matchingDict = (CFMutableDictionaryRef) CFRetain(matchingDict);
	
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
		NSLog(@"[%@ %s]: Couldn't register port for match\n", [self class], (char *) _cmd);
	}
	
	
	matched_callback(self, matchedIterator);
	
	
	kr = IOServiceAddMatchingNotification(notification_port, 
										  kIOTerminatedNotification, 
										  matchingDict,
										  removed_callback,
										  self, 
										  &matchedIterator);
	if(kr != kIOReturnSuccess) {
		NSLog(@"[%@ %s]: Couldn't register port for match\n", [self class], (char *) _cmd);
	}
	
	removed_callback(self, matchedIterator);
	
	while(running) 
		[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
	
	NSLog(@"[%@ %s]: Run loop stopped\n", [self class], (char *) _cmd);
}

-(void)readAsyncPipe6:(NSMutableData *) data {
	kern_return_t kr;
	
	if((*ozyUSBInterface)->GetPipeStatus(ozyUSBInterface, ep6Pipe) != kIOReturnSuccess) {
		NSLog(@"[%@ %s]: Pipe 6 Stalled.\n", [self class], (char *) _cmd);
		(*ozyUSBInterface)->ClearPipeStallBothEnds(ozyUSBInterface, ep6Pipe);
	}	
	
	OzyCallbackData *callbackData = [OzyCallbackData ozyCallbackData:data andInterface:self];
	[callbacks addObject:callbackData];
	
	kr = (*ozyUSBInterface)->ReadPipeAsyncTO(ozyUSBInterface, ep6Pipe, [data mutableBytes], [data length], 1000, 2000, (IOAsyncCallback1) ep6_callback, callbackData);
	if(kr != kIOReturnSuccess) {
		NSLog(@"[%@ %s]: Could not read from pipe (%08x)\n", [self class], (char *) _cmd, kr);
		return;
	}
}

-(void)fillHeader:(char *)header {
	
	memset(header, 0, 5);
	
	switch(headerSequence) {
		case 0:
			if(mox == TRUE) {
				header[0] = 0x01;
			} else {
				header[0] = 0x00;
			}
			
			if(sampleRate == 192000) {
				header[1] = 0x02;
			} else if(sampleRate == 96000) {
				header[1] = 0x01;
			} else {
				header[1] = 0x00;
			}
			
			if(tenMHzSource == MERCURY) {
				header[1] |= 0x08;
			} else if(tenMHzSource == PENELOPE) {
				header[1] |= 0x04;
			}
			
			if(oneTwentyTwoMHzSource == MERCURY) {
				header[1] |= 0x10;
			}
			
			if(penelopePresent == TRUE) {
				header[1] |= 0x20;
			} 			
			if (mercuryPresent == TRUE) {
				header[1] |= 0x40;
			}
			
			if(micSource == PENELOPE) {
				header[1] |= 0x80;
			}
			
			if(classE == TRUE) {
				header[2] = 0x01;
			} else {
				header[2] = 0x00;
			}
			
			header[2] |= openCollectors;
			
			if(alexAttenuator == 10) {
				header[3] = 0x01;
			} else if(alexAttenuator == 20) {
				header[3] = 0x02;
			} else if(alexAttenuator == 30) {
				header[3] = 0x03;
			} else {
				header[3] = 0x00;
			}
			
			if(preamp == TRUE) {
				header[3] |= 0x04;
			}
			
			if(dither == TRUE) {
				header[3] |= 0x08;
			}
			
			if(random == TRUE) {
				header[3] |= 0x10;
			}
			
			if(alexAntenna == 1) {
				header[3] |= 0x20;
			} else if(alexAntenna == 2) {
				header[3] |= 0x40;
			} else if(alexAntenna == XVERTER) {
				header[3] |= 0x60;
			}
			
			if(alexRxOut == TRUE) {
				header[3] |= 0x80;
			}
			
			if(alexTxRelay == 1) {
				header[4] = 0x00;
			} else if(alexTxRelay == 2) {
				header[4] = 0x01;
			} else if(alexTxRelay == 3) {
				header[4] = 0x02;
			}
			
			if(duplex == TRUE) {
				header[4] |= 0x04;
			}
			
			// handle number of receivers here
			
			++headerSequence;
			break;
		case 1:
			header[0] = 0x02;
			
			if(mox == TRUE) {
				header[0] |= 0x01;
			}
			
			if(duplex == TRUE) {
				header[1] = transmitterFrequency >> 24;
				header[2] = transmitterFrequency >> 16;
				header[3] = transmitterFrequency >> 8;
				header[4] = transmitterFrequency;
				++headerSequence;
			} else {
				header[1] = receiverFrequency[0] >> 24;
				header[2] = receiverFrequency[0] >> 16;
				header[3] = receiverFrequency[0] >> 8;
				header[4] = receiverFrequency[0];
				headerSequence = 9;
			}
			break;
		case 2:
			header[0] = 0x04;
			
			if(mox == TRUE) {
				header[0] |= 0x01;
			}
			
			header[1] = receiverFrequency[0] >> 24;
			header[2] = receiverFrequency[0] >> 16;
			header[3] = receiverFrequency[0] >> 8;
			header[4] = receiverFrequency[0];
			
			++headerSequence;
			break;
		case 3:
			header[0] = 0x06;
			
			if(mox == TRUE) {
				header[0] |= 0x01;
			}
			
			header[1] = receiverFrequency[1] >> 24;
			header[2] = receiverFrequency[1] >> 16;
			header[3] = receiverFrequency[1] >> 8;
			header[4] = receiverFrequency[1];
			
			++headerSequence;
			break;
		case 4:
			header[0] = 0x08;
			
			if(mox == TRUE) {
				header[0] |= 0x01;
			}
			
			header[1] = receiverFrequency[2] >> 24;
			header[2] = receiverFrequency[2] >> 16;
			header[3] = receiverFrequency[2] >> 8;
			header[4] = receiverFrequency[2];
			
			++headerSequence;
			break;
		case 5:
			header[0] = 0x0A;
			
			if(mox == TRUE) {
				header[0] |= 0x01;
			}
			
			header[1] = receiverFrequency[3] >> 24;
			header[2] = receiverFrequency[3] >> 16;
			header[3] = receiverFrequency[3] >> 8;
			header[4] = receiverFrequency[3];
			
			++headerSequence;
			break;
		case 6:
			header[0] = 0x0C;
			
			if(mox == TRUE) {
				header[0] |= 0x01;
			}
			
			header[1] = receiverFrequency[4] >> 24;
			header[2] = receiverFrequency[4] >> 16;
			header[3] = receiverFrequency[4] >> 8;
			header[4] = receiverFrequency[4];
			
			++headerSequence;
			break;
		case 7:
			header[0] = 0x0E;
			
			if(mox == TRUE) {
				header[0] |= 0x01;
			}
			
			header[1] = receiverFrequency[5] >> 24;
			header[2] = receiverFrequency[5] >> 16;
			header[3] = receiverFrequency[5] >> 8;
			header[4] = receiverFrequency[5];
			
			++headerSequence;
			break;			
		case 8:
			header[0] = 0x10;
			
			if(mox == TRUE) {
				header[0] |= 0x01;
			}
			
			header[1] = receiverFrequency[6] >> 24;
			header[2] = receiverFrequency[6] >> 16;
			header[3] = receiverFrequency[6] >> 8;
			header[4] = receiverFrequency[6];
			
			++headerSequence;
			break;
		case 9:
			header[0] = 0x12;
			
			if(mox == TRUE) {
				header[0] |= 0x01;
			}
			
			header[1] = driveLevel;
			
			if(micBoost == 20) {
				header[2] = 0x01;
			}
			headerSequence = 0;
	}	
}

-(void)writeData {
	kern_return_t kr;

	if ([outputBuffer entries] < OZY_BUFFER_DATA_SIZE) {
		NSLog(@"[%@ %s]: Called without sufficient stuff in the buffer\n", [self class], (char *) _cmd);
		return;
	}
	@synchronized(outputBuffer) {
		NSData *buffer = [outputBuffer get:OZY_BUFFER_DATA_SIZE];
		const unsigned char *bytes = [buffer bytes];
		
		mox = NO;
		for(int i = 5; i < OZY_BUFFER_DATA_SIZE; i += 8) {
			if(bytes[i] != 0x00) {
				mox = YES;
				break;
			}
		}
				
		for(int i = 0; i < OZY_PACKETS_PER_INPUT_BUFFER; ++i) {
			[self fillHeader:outputPacket[i].header];
			memcpy(outputPacket[i].samples, bytes, sizeof(outputPacket[i].samples));
			bytes += sizeof(outputPacket[i].samples);
		}
		
		if((*ozyUSBInterface)->GetPipeStatus(ozyUSBInterface, ep2Pipe) != kIOReturnSuccess) {
			NSLog(@"[%@ %s]: Pipe 2 Stalled.\n", [self class], (char *) _cmd);
			(*ozyUSBInterface)->ClearPipeStallBothEnds(ozyUSBInterface, ep2Pipe);
		}
				
		kr = (*ozyUSBInterface)->WritePipeAsyncTO(ozyUSBInterface, ep2Pipe, (void *) &outputPacket, sizeof(outputPacket), 100, 200, (IOAsyncCallback1) ep2_callback, NULL);
		if(kr != kIOReturnSuccess) {
			NSLog(@"[%@ %s]: USB Write failed (%08x)\n", [self class], (char *) _cmd, kr);
			return;
		}
	}
}

-(void)kickStart {
	OzyPacket wakeupPacket[17];
	kern_return_t kr;
	
	NSLog(@"[%@ %s]: Kickstarting Ozy\n", [self class], (char *) _cmd);
	
	for(int i = 0; i < 17; ++i) {
		wakeupPacket[i].magic[0] = SYNC;
		wakeupPacket[i].magic[1] = SYNC;
		wakeupPacket[i].magic[2] = SYNC;
		[self fillHeader:wakeupPacket[i].header];
		memset(wakeupPacket[i].samples, 0, sizeof(wakeupPacket[i].samples));
	}
	
	if((*ozyUSBInterface)->GetPipeStatus(ozyUSBInterface, ep2Pipe) != kIOReturnSuccess) {
		NSLog(@"[%@ %s]: Pipe 2 Stalled.\n", [self class], (char *) _cmd);
		(*ozyUSBInterface)->ClearPipeStallBothEnds(ozyUSBInterface, ep2Pipe);
	}
	
	kr = (*ozyUSBInterface)->WritePipeAsyncTO(ozyUSBInterface, ep2Pipe, (void *) &wakeupPacket, sizeof(wakeupPacket), 100, 200, (IOAsyncCallback1) ep2_callback, NULL);
	if(kr != kIOReturnSuccess) {
		NSLog(@"[%@ %s]: USB Write failed (%08x)\n", [self class], (char *) _cmd, kr);
		return;
	}
}	

-(void)ep6Callback: (NSMutableData *)inputBuffer length: (UInt32)bytes{
	if(inputBuffer == NULL) return;
	
	NSMutableData *newOzyBuffer = [ep6Buffers getFreeBuffer];
	if(newOzyBuffer == NULL) {
		NSLog(@"[%@ %s]: Can't get a new buffer off the stack\n", [self class], (char *) _cmd);
	}
	[self readAsyncPipe6:newOzyBuffer];
	if (bytes == 0) {
		NSLog(@"[%@ %s]: OzyBulkRead read failed %d\n", [self class], (char *) _cmd, bytes);
		[ep6Buffers freeBuffer:inputBuffer];
		ep4Started = NO;
	} else if (bytes != OZY_BUFFER_SIZE) {
		NSLog(@"[%@ %s]: OzyBulkRead only read %d bytes\n",[self class], (char *) _cmd, bytes);
		[self kickStart];
		[ep6Buffers freeBuffer:inputBuffer];
		ep4Started = NO;
	} else {
		[ep6Buffers putInputBuffer:inputBuffer];
		semaphore_signal([ep6Buffers ozyInputBufferSemaphore]);
		
		// XXX FIX ME
		/*if(ep4Started == NO) {
			// Kick off the ep4 read chain
			NSMutableData *newBuffer = [ep4Buffers getFreeBuffer];
			if(newBuffer != NULL ) {
				ep4Started = YES;
				[self readAsyncPipe4:newBuffer];
			}
		}	*/		
	}
 	
	if([outputBuffer entries] >= OZY_BUFFER_DATA_SIZE) {
		[self writeData];
	}
}

-(void)beginReadChains {
	[self kickStart];
	
	NSMutableData *newBuffer = [ep6Buffers getFreeBuffer];
	if(newBuffer != NULL ) {
		[self readAsyncPipe6:newBuffer];
	}
	
}

-(void)ep6ProcessingThread {
	struct thread_time_constraint_policy ttcpolicy;
	mach_timebase_info_data_t tTBI;
	double mult;
	
	NSMutableData *ozyBuffer;
	OzyPacket *ozyPackets;
	OzySamplesIn *inSamples;
	
	NSMutableData *sampleData = [NSMutableData dataWithLength:sizeof(OzySamplesOut) * 256];
	OzySamplesOut *outBuffer = (OzySamplesOut *) [sampleData mutableBytes];
	
	int samples = 0;
		
	mach_timebase_info(&tTBI);
	mult = ((double)tTBI.denom / (double)tTBI.numer) * 1000000;
	
	ttcpolicy.period = 12 * mult;
	ttcpolicy.computation = 2 * mult;
	ttcpolicy.constraint = 24 * mult;
	ttcpolicy.preemptible = 0;
	
	if((thread_policy_set(mach_thread_self(), THREAD_TIME_CONSTRAINT_POLICY, (thread_policy_t) &ttcpolicy, THREAD_TIME_CONSTRAINT_POLICY_COUNT)) != KERN_SUCCESS) {
		NSLog(@"[%@ %s]:  Failed to set callback to realtime\n", [self class], (char *) _cmd);
	} 	
	
	while(running) {
		semaphore_wait([ep6Buffers ozyInputBufferSemaphore]);
		
		ozyBuffer = [ep6Buffers getInputBuffer];
		
		if(ozyBuffer == NULL) {
			NSLog(@"[%@ %s]: Couldn't get Ozy input buffer.\n", [self class], (char *) _cmd);
			continue;
		}
		if([ozyBuffer bytes] == NULL) {
			NSLog(@"[%@ %s]: Ozy buffer doesn't contain anything\n", [self class], (char *) _cmd);
			continue;
		}
		
		ozyPackets = (OzyPacket *) [ozyBuffer bytes];
		for(int i = 0; i < OZY_PACKETS_PER_INPUT_BUFFER; ++i) {
			if(ozyPackets[i].magic[0] != SYNC || ozyPackets[i].magic[1] != SYNC ||ozyPackets[i].magic[2] != SYNC) {
				NSLog(@"[%@ %s]: Invalid Ozy packet recieved\n", [self class], (char *) _cmd);
				continue;
			}
			
			ptt = (ozyPackets[i].header[0] & 0x01) ? YES : NO;
			dash = (ozyPackets[i].header[0] & 0x02) ? YES : NO;
			dot = (ozyPackets[i].header[0] & 0x04) ? YES : NO;
			
			switch(ozyPackets[i].header[0] >> 3) {
				case 0x00:
					ADCOverflow = (ozyPackets[i].header[1] & 0x01) ? YES : NO;
					if(mercuryVersion != ozyPackets[i].header[2]) {
						[self willChangeValueForKey:@"mercuryVersion"];
						mercuryVersion = ozyPackets[i].header[2];
						[self didChangeValueForKey:@"mercuryVersion"];
					}
					if(penelopeVersion != ozyPackets[i].header[3]) {
						[self willChangeValueForKey:@"penelopeVersion"];
						penelopeVersion = ozyPackets[i].header[3];
						[self didChangeValueForKey:@"penelopeVersion"];
					}
					if(ozyVersion != ozyPackets[i].header[4]) {
						[self willChangeValueForKey:@"ozyVersion"];
						ozyVersion =ozyPackets[i]. header[4];
						[self didChangeValueForKey:@"ozyVersion"];
					}
					break;
				case 0x01:
					forwardPower = (ozyPackets[i].header[1] << 8) + ozyPackets[i].header[2];
					break;
                case 0x02:
                    // Reverse power from Alex/Apollo in header[1] & header[2]
                    // AIN3 from Penny/Hermes in header[3] & header[4]
                    break;
                case 0x03:
                    //  AIN4 from Penny/Hermes in header[1] & header[2]
                    //  AIN6 from Penny/Hermes in header[3] & header[4] (13.8V on Hermes)
                    break;
				default:
					NSLog(@"[%@ %s] Invalid Ozy packet header: %08x\n", [self class], (char *) _cmd, ozyPackets[i].header[0]);
					continue;
			}
			
			for(int j = 0; j < 63; ++j) {
				inSamples = &(ozyPackets[i].samples[j]);
				
				leftInputBuffer[samples] = (float)((signed char) inSamples->i[0] << 16 |
												   (unsigned char) inSamples->i[1] << 8 |
												   (unsigned char) inSamples->i[2]) / 8388607.0f;
				rightInputBuffer[samples] = (float)((signed char) inSamples->q[0] << 16 |
													(unsigned char) inSamples->q[1] << 8 |
													(unsigned char) inSamples->q[2]) / 8388607.0f;
				leftMicBuffer[samples] = rightMicBuffer[samples] = (float)(CFSwapInt16BigToHost(inSamples->mic)) / 32767.0f * micGain;
				++samples;
				
				if(samples == DTTSP_BUFFER_SIZE) {
					[sdr audioCallbackForThread: 0 realIn:leftInputBuffer imagIn:rightInputBuffer realOut:leftOutputBuffer imagOut:rightOutputBuffer size:DTTSP_BUFFER_SIZE];
					
					if(ptt == YES) {
						[sdr audioCallbackForThread: 1 realIn:leftMicBuffer imagIn:rightMicBuffer realOut:leftTxBuffer imagOut:rightTxBuffer size:DTTSP_BUFFER_SIZE];
					}
					
					for(int k = 0, c = 0; k < DTTSP_BUFFER_SIZE; k += outputSampleIncrement) {
						outBuffer[c].leftRx = CFSwapInt16HostToBig((int16_t)(leftOutputBuffer[k] * 32767.0f));
						outBuffer[c].rightRx = CFSwapInt16HostToBig((int16_t)(rightOutputBuffer[k] * 32767.0f));
						
						if(ptt == YES) {
							outBuffer[c].leftTx = CFSwapInt16HostToBig((int16_t) (leftTxBuffer[k] * 32767.0f * txGain));
							outBuffer[c].rightTx = CFSwapInt16HostToBig((int16_t) (rightTxBuffer[k] * 32767.0f * txGain));
						} else {
							outBuffer[c].leftTx = 0;
							outBuffer[c].rightTx = 0;
						}
						
						if(c++ == 255) {
							[outputBuffer put:sampleData];
							c = 0;
						}
					}
					samples = 0;
				}
			}
		}
			
		[ep6Buffers freeBuffer: ozyBuffer];
	}	
}

@end

void matched_callback(void *inputData, io_iterator_t iterator) {
	NNHOzyDriver *self = (NNHOzyDriver *)inputData;
	
	[self matchedCallback: IOIteratorNext(iterator)];
	while(IOIteratorNext(iterator));
}

void removed_callback(void *inputData, io_iterator_t iterator) {
	NNHOzyDriver *self = (NNHOzyDriver *)inputData;
	
	[self removedCallback: IOIteratorNext(iterator)];
	while(IOIteratorNext(iterator));
}

void ep6_callback(void *callback_data, IOReturn result, void *arg0) {
	OzyCallbackData *ozyData = (OzyCallbackData *)callback_data;
	
	[[ozyData interface] ep6Callback: [ozyData data] length:(UInt32) arg0];
	[[[ozyData interface] callbacks] removeObject:ozyData];
}

void ep2_callback(void *callback_data, IOReturn result, void *arg0) {
}
