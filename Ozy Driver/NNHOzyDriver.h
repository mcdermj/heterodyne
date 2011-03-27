//
//  NNHOzyDriver.h
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

#import <Cocoa/Cocoa.h>

#include <IOKit/IOKitLib.h>
#include <IOKit/IOCFPlugIn.h>
#include <IOKit/usb/IOUSBLib.h>

#import "XTHeterodyneHardwareDriver.h"

#define VRQ_SDR1K_CTL 0x0d;
#define SDR1KCTRL_READ_VERSION 0x7;
#define	VRT_VENDOR_IN 0xC0;

#define MAX_EP0_PACKET_SIZE 64

#define VENDOR_REQ_TYPE_OUT 0x40
#define VENDOR_REQ_FPGA_LOAD 0x02
#define VENDOR_REQ_I2C_WRITE 0x08
#define FIRMWARE_LOAD_BEGIN 0x00
#define FIRMWARE_LOAD_XFER 0x01
#define FIRMWARE_LOAD_END 0x02

typedef struct _ozySamplesIn {
	char i[3];
	char q[3];
	short mic;
} __attribute__((packed)) OzySamplesIn;

typedef struct _ozySamplesOut {
	int16_t leftRx;
	int16_t rightRx;
	int16_t leftTx;
	int16_t rightTx;
} __attribute__((packed)) OzySamplesOut;

typedef struct _ozyPacket {
	char magic[3];
	char header[5];
	OzySamplesIn samples[63];
} __attribute__((packed)) OzyPacket;

#define OZY_PACKET_SIZE sizeof(OzyPacket)
#define OZY_PACKETS_PER_INPUT_BUFFER 17
#define OZY_BUFFER_SIZE (OZY_PACKET_SIZE * OZY_PACKETS_PER_INPUT_BUFFER)
#define OZY_BUFFER_HEADER_SIZE (OZY_PACKETS_PER_INPUT_BUFFER * 8)
#define OZY_BUFFER_DATA_SIZE (OZY_BUFFER_SIZE - OZY_BUFFER_HEADER_SIZE)

#define SYNC 0x7F

#define MERCURY 0
#define PENELOPE 1
#define JANUS 2
#define ATLAS 4
#define BOTH 5

#define XVERTER 3

#define DTTSP_BUFFER_SIZE 1024

@class XDTTSP;
@class OzyInputBuffers;
@class OzyRingBuffer;

@interface NNHOzyDriver : NSObject <XTHeterodyneHardwareDriver> {
	
	XTDTTSP *sdr;
	
	int outputSampleIncrement;
	int headerSequence;
	int sampleRate;
	
	IBOutlet NSView *configWindow;
	
	IOUSBInterfaceInterface190 **ozyUSBInterface;
	IOUSBDeviceInterface187 **ozyUSBDevice;
	
	int ep6Pipe;
	int ep4Pipe;
	int ep2Pipe;

	BOOL FPGALoaded;
	BOOL FXLoaded;
	BOOL running;
	
	BOOL ep4Started;
	
	OzyInputBuffers *ep6Buffers;
	OzyRingBuffer *outputBuffer;
	
	OzyPacket outputPacket[OZY_PACKETS_PER_INPUT_BUFFER];
	
	BOOL mox;
	
	int receiverFrequency[8];
	
	UInt8 openCollectors;
	
	NSMutableArray *callbacks;
	
	BOOL ptt;
	BOOL dot;
	BOOL dash;
	
	BOOL ADCOverflow;
	
	int forwardPower;
	
	float leftInputBuffer[DTTSP_BUFFER_SIZE];
	float rightInputBuffer[DTTSP_BUFFER_SIZE];

	float leftMicBuffer[DTTSP_BUFFER_SIZE];
	float rightMicBuffer[DTTSP_BUFFER_SIZE];
	
	float leftOutputBuffer[DTTSP_BUFFER_SIZE];
	float rightOutputBuffer[DTTSP_BUFFER_SIZE];
	
	float leftTxBuffer[DTTSP_BUFFER_SIZE];
	float rightTxBuffer[DTTSP_BUFFER_SIZE];
	
	float micGain;
	float txGain;
	
	//  ivars
	int ozyVersion;
	int penelopeVersion;
	int mercuryVersion;
	
	short tenMHzSource;
	short oneTwentyTwoMHzSource;
	BOOL penelopePresent;
	BOOL mercuryPresent;
	short micSource;
	BOOL classE;
	short alexAttenuator;
	BOOL preamp;
	BOOL dither;
	BOOL random;
	short alexAntenna;
	BOOL alexRxOut;
	short alexTxRelay;
	BOOL duplex;
	int transmitterFrequency;
	short driveLevel;
	short micBoost;
	NSString *fx2Version;
	
}

@property int ozyVersion;
@property int penelopeVersion;
@property int mercuryVersion;

@property short tenMHzSource;
@property short oneTwentyTwoMHzSource;
@property BOOL penelopePresent;
@property BOOL mercuryPresent;
@property short micSource;
@property BOOL classE;
@property short alexAttenuator;
@property BOOL preamp;
@property BOOL dither;
@property BOOL random;
@property short alexAntenna;
@property BOOL alexRxOut;
@property short alexTxRelay;
@property BOOL duplex;
@property int transmitterFrequency;
@property short driveLevel;
@property short micBoost;
@property (readonly) NSMutableArray *callbacks;
@property (readonly) NSString *fx2Version;


-(id)initWithSDR:(XTDTTSP *)sdr;

@end

@interface OzyCallbackData : NSObject {
	// ivars
	NNHOzyDriver *interface;
	NSMutableData *data;
}

@property (readonly) NNHOzyDriver *interface;
@property (readonly) NSMutableData *data;

+(id)ozyCallbackData:(NSMutableData *)data andInterface:(NNHOzyDriver *)interface;
-(id)initWithData:(NSMutableData *)newData andInterface:(NNHOzyDriver *)newInterface;

@end

void matched_callback(void *inputData, io_iterator_t iterator);
void removed_callback(void *inputData, io_iterator_t iterator);

void ep6_callback(void *ozy_buffer, IOReturn result, void *arg0);
void ep2_callback(void *callback_data, IOReturn result, void *arg0);