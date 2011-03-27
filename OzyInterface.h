//
//  OzyInterface.h
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

#import <Cocoa/Cocoa.h>

#import "OzyInputBuffers.h"
#import "OzyRingBuffer.h"
#import "SystemAudioThread.h"

#include "Accelerate/Accelerate.h"
#include <netinet/in.h>

#define BANDSCOPE_BUFFER_SIZE 8192

#define SYNC 0x7F

#define DTTSP_BUFFER_SIZE 1024

#define MERCURY 0
#define PENELOPE 1
#define JANUS 2
#define ATLAS 4
#define BOTH 5

#define XVERTER 3

typedef struct _ozySamplesOut {
	int16_t leftRx;
	int16_t rightRx;
	int16_t leftTx;
	int16_t rightTx;
} __attribute__((packed)) OzySamplesOut;

typedef struct _metisDataHeader {
	unsigned short magic;
	char opcode;
	char endpoint;
	unsigned int sequence;
} __attribute__((packed)) MetisDataHeader;

typedef struct _ozySamplesIn {
	char i[3];
	char q[3];
	short mic;
} __attribute__((packed)) OzySamplesIn;

typedef struct _ozyPacket {
	char magic[3];
	char header[5];
	OzySamplesIn samples[63];
} __attribute__((packed)) OzyPacket;

typedef struct _metisPacket {
	MetisDataHeader header;
	OzyPacket packets[2];
} __attribute__((packed)) MetisPacket;

typedef struct _metisDiscoveryRequest{
	short magic;
	char opcode;
	char padding[60];
} __attribute__((packed)) MetisDiscoveryRequest;

typedef struct _metisDiscoveryReply {
	short magic;
	char opcode;
	unsigned int ip;
	char mac[6];
} __attribute__((packed)) MetisDiscoveryReply;

typedef struct _metisStartStop {
	short magic;
	char opcode;
	char startStop;
	char padding[60];
} __attribute__((packed)) MetisStartStop;


@interface OzyInterface : NSObject {	
	NSMutableData *ozySampleData;
	OzySamplesOut *ozyOutBuffer;
	
	NSMutableData *systemSampleData;
		
	int transmitterFrequency;
	int receiverFrequency[8];	
	
	OzyInputBuffers *ep6Buffers;
	OzyRingBuffer *outputBuffer;
	OzyRingBuffer *audioBuffer;
	
	NSOperationQueue *operationQueue;
	
	SystemAudioThread *audioThread;
	
	BOOL ADCOverflow;
	
	int mercuryVersion;
	int penelopeVersion;
	int ozyVersion;
		
	int forwardPower;
	
	float leftInputBuffer[DTTSP_BUFFER_SIZE];
	float rightInputBuffer[DTTSP_BUFFER_SIZE];
	float leftOutputBuffer[DTTSP_BUFFER_SIZE];
	float rightOutputBuffer[DTTSP_BUFFER_SIZE];
	float leftMicBuffer[DTTSP_BUFFER_SIZE];
	float rightMicBuffer[DTTSP_BUFFER_SIZE];
	float leftTxBuffer[DTTSP_BUFFER_SIZE];
	float rightTxBuffer[DTTSP_BUFFER_SIZE];
	int samples;
	DSPSplitComplex systemBuffer;
	
	int outputSampleIncrement;
	
	int headerSequence;
	
	BOOL mox;
	BOOL preamp;
	BOOL dither;
	BOOL random;
	BOOL alexRxOut;
	BOOL duplex;
	BOOL classE;
	BOOL mercuryAudio;
	BOOL systemAudio;
	BOOL mercuryPresent;
	BOOL penelopePresent;
	
	BOOL ptt;
	BOOL dot;
	BOOL dash;
	
	int sampleRate;
	short tenMHzSource;	
	short oneTwentyTwoMHzSource;		
	short micSource;	
	short alexAttenuator;	
	short alexAntenna;	
	short alexTxRelay;	
	short driveLevel;
	short micBoost;
	
	UInt8 openCollectors;
	
	float micGain;
	float txGain;
	
	CFSocketRef metisSocket;
	unsigned int metisWriteSequence;
	struct sockaddr_in metisAddressStruct;
	
	BOOL running;
}

@property (readonly) OzyInputBuffers *ep4Buffers;
@property (readonly) SystemAudioThread *audioThread;
@property (readonly) int mercuryVersion;
@property (readonly) int ozyVersion;
@property (readonly) int penelopeVersion;
@property (readonly) NSString *ozyFXVersion;

@property int sampleRate;
@property BOOL dither;
@property BOOL random;
@property short tenMHzSource;
@property short oneTwentyTwoMHzSource;
@property BOOL systemAudio;
@property BOOL mercuryPresent;
@property BOOL penelopePresent;
@property BOOL preamp;

@property UInt8 openCollectors;

@property float micGain;
@property float txGain;

-(id)init;

-(void)kickStart;
-(void)processInputBuffer:(NSData *)buffer;

-(void)setFrequency: (int)_frequency forReceiver: (int)_receiver;
-(int)getFrequency: (int)_receiver;

-(void)notifyBandscopeWatchers;

-(void)loadParams;

-(void)awakeFromNib;

@end