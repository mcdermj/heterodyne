//
//  OzyInterface.m
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

#import "OzyInterface.h"

#import "dttsp.h"

#include <arpa/inet.h>
#include <mach/mach_time.h>
#include <sys/time.h>


@implementation OzyInterface

@synthesize ep4Buffers;
@synthesize audioThread;
@synthesize systemAudio;
@synthesize dither;
@synthesize random;
@synthesize tenMHzSource;
@synthesize oneTwentyTwoMHzSource;
@synthesize mercuryPresent;
@synthesize penelopePresent;
@synthesize sampleRate;
@synthesize mercuryVersion;
@synthesize ozyVersion;
@synthesize penelopeVersion;
@synthesize preamp;
@synthesize openCollectors;
@synthesize micGain;
@synthesize txGain;


-(id)init
{
	self = [super init];
	
	if(self) {	
		
		mox = FALSE;
		preamp = FALSE;
		alexRxOut = FALSE;
		duplex = FALSE;
		classE = FALSE;
		
		micSource = PENELOPE;
		alexAttenuator = 0;
		alexAntenna = 0;
		alexTxRelay = 0;
		driveLevel = 0;
		micBoost = 0;
		
		openCollectors = 0x0;
		
		mercuryAudio = TRUE;
		
		micGain = 1.0f;
		txGain = 1.0f;
		
		transmitterFrequency = receiverFrequency[0] = [[NSUserDefaults standardUserDefaults] integerForKey:@"receiverFrequency"];
			
		operationQueue = [[NSOperationQueue alloc] init];
			
		ep6Buffers = [[OzyInputBuffers alloc] initWithSize:sizeof(MetisPacket) quantity:512];
		ep4Buffers = [[OzyInputBuffers alloc] initWithSize:BANDSCOPE_BUFFER_SIZE quantity: 16];
		outputBuffer = [[OzyRingBuffer alloc] initWithEntries:(128 * sizeof(MetisPacket)) andName:@"Metis Output Buffer"];
		audioBuffer = [[OzyRingBuffer alloc] initWithEntries:(128 * sizeof(MetisPacket)) andName:@"Audio Output Buffer"];
				
		[self loadParams];
		
		systemSampleData = [NSMutableData dataWithLength:2048 * sizeof(float)];
		systemBuffer.realp = leftOutputBuffer;
		systemBuffer.imagp = rightOutputBuffer;	
		
		ozySampleData = [NSMutableData dataWithLength:sizeof(OzySamplesOut) * 128];
		ozyOutBuffer = (OzySamplesOut *) [ozySampleData mutableBytes];		
		
		//  Create a socket to communicate with Metis
		CFSocketContext socketContext = { 0, self, NULL, NULL, NULL };
		metisSocket = CFSocketCreate(kCFAllocatorDefault, 
									 PF_INET, SOCK_DGRAM, 
									 IPPROTO_UDP, 
									 kCFSocketNoCallBack,
									 NULL, 
									 &socketContext);
		CFRetain(metisSocket);
		
		//  Bind it to port 1024
		struct sockaddr_in bindAddress;
		bindAddress.sin_len = sizeof(bindAddress);
		bindAddress.sin_family = AF_INET;
		bindAddress.sin_port = htons(1024);
		bindAddress.sin_addr.s_addr = htonl(INADDR_ANY);
		
		
		CFSocketError error = CFSocketSetAddress(metisSocket, 
												 (CFDataRef) [NSData dataWithBytes:&bindAddress 
																			length:sizeof(bindAddress)]); 
		if(error != kCFSocketSuccess) {
			NSLog(@"Couldn'g bind socket\n");
		}		
		
		metisAddressStruct.sin_len = sizeof(metisAddressStruct);
		metisAddressStruct.sin_family = AF_INET;
		metisAddressStruct.sin_port = htons(1024);

		metisWriteSequence = 0;
		
		}
	
	return self;
}

-(void)loadParams {
	self.sampleRate = [[NSUserDefaults standardUserDefaults] integerForKey:@"sampleRate"];
	self.dither = [[NSUserDefaults standardUserDefaults] boolForKey:@"dither"];
	self.random = [[NSUserDefaults standardUserDefaults] boolForKey:@"random"];
	self.tenMHzSource = [[NSUserDefaults standardUserDefaults] integerForKey:@"tenMHzSource"];
	self.oneTwentyTwoMHzSource = [[NSUserDefaults standardUserDefaults] integerForKey:@"oneTwentyTwoMHzSource"];
	self.mercuryPresent = [[NSUserDefaults standardUserDefaults] boolForKey:@"mercuryPresent"];
	self.penelopePresent = [[NSUserDefaults standardUserDefaults] boolForKey:@"penelopePresent"];
	self.micGain = [[NSUserDefaults standardUserDefaults] floatForKey:@"micGain"];
	self.txGain = [[NSUserDefaults standardUserDefaults] floatForKey:@"txGain"];
	
	openCollectors = 0x00;
	for (int i = 1; i < 8; ++i) {
		NSString *collectorName = [NSString stringWithFormat:@"oc%d", i];
		if([[NSUserDefaults standardUserDefaults] boolForKey:collectorName] == YES) {
			openCollectors |= (UInt8) (0x01 << i);
		}
	}
}

-(NSString *)ozyFXVersion {	
		return @"NO FX2";
}

-(void)processInputBuffer:(NSData *)buffer {
    int c = 0;
	int k = 0;
	
	OzyPacket *currentOzyPacket;
	OzySamplesIn *inSamples;
			
	float *systemSamples = [systemSampleData mutableBytes];
	
	MetisPacket *packet = (MetisPacket *) [buffer bytes];
	
	for(int i = 0; i < 2; ++i) {
		currentOzyPacket = &(packet->packets[i]);
		
		if(currentOzyPacket->magic[0] != SYNC || currentOzyPacket->magic[1] != SYNC || currentOzyPacket->magic[2] != SYNC) {
			NSLog(@"[%@ %s] Invalid Ozy packet received from Metis\n", [self class], (char *) _cmd);
			continue;
		}
		
		//NSLog(@"Header Byte %x\n", currentOzyPacket->header[0]);
		//ptt = (currentOzyPacket->header[0] & 0x01) ? YES : NO;
		dash = (currentOzyPacket->header[0] & 0x02) ? YES : NO;
		dot = (currentOzyPacket->header[0] & 0x04) ? YES : NO;
		
		switch(currentOzyPacket->header[0] >> 3) {
			case 0x00:
				ADCOverflow = (currentOzyPacket->header[1] & 0x01) ? YES : NO;
				mercuryVersion = currentOzyPacket->header[2];
				penelopeVersion = currentOzyPacket->header[3];
				ozyVersion = currentOzyPacket->header[4];
				break;
			case 0x01:
				forwardPower = (currentOzyPacket->header[1] << 8) + currentOzyPacket->header[2];
				break;
			default:
				NSLog(@"[%@ %s] Invalid Ozy packet header\n", [self class], (char *) _cmd);
				continue;
		}
		
		for(int j = 0; j < 63; ++j) {
			inSamples = &(currentOzyPacket->samples[j]);
			leftInputBuffer[samples] = (float)((signed char) inSamples->i[0] << 16 |
												(unsigned char) inSamples->i[1] << 8 |
												(unsigned char) inSamples->i[2]) / 8388607.0f;
			rightInputBuffer[samples] = (float)((signed char) inSamples->q[0] << 16 |
											   (unsigned char) inSamples->q[1] << 8 |
											   (unsigned char) inSamples->q[2]) / 8388607.0f;
			leftMicBuffer[samples] = (float)(CFSwapInt16BigToHost(inSamples->mic)) / 32767.0f * micGain;
			++samples;
			
			if(samples == DTTSP_BUFFER_SIZE) {
				Audio_Callback(leftInputBuffer, rightInputBuffer, leftOutputBuffer, rightOutputBuffer, DTTSP_BUFFER_SIZE, 0);
				
				if(ptt == YES) {
					memset(rightMicBuffer, 0, DTTSP_BUFFER_SIZE);
					Audio_Callback(leftMicBuffer, rightMicBuffer, leftTxBuffer, rightTxBuffer, DTTSP_BUFFER_SIZE, 1);
				}
				
				for(k = 0; k < DTTSP_BUFFER_SIZE; k += outputSampleIncrement) {
					ozyOutBuffer[c].leftRx = CFSwapInt16HostToBig((int16_t)(leftOutputBuffer[k] * 32767.0f));
					ozyOutBuffer[c].rightRx = CFSwapInt16HostToBig((int16_t)(rightOutputBuffer[k] * 32767.0f));
					
					if(ptt == YES) {
						ozyOutBuffer[c].leftTx = CFSwapInt16HostToBig((int16_t) (leftTxBuffer[k] * 32767.0f * txGain));
						ozyOutBuffer[c].rightTx = CFSwapInt16HostToBig((int16_t) (rightTxBuffer[k] * 32767.0f * txGain));
					} else {
						ozyOutBuffer[c].leftTx = 0;
						ozyOutBuffer[c].rightTx = 0;
					}
					
					++c;
					
					if(c == 128) {
						[outputBuffer put:ozySampleData];
						c = 0;
					}
				}
				
				vDSP_ztoc(&systemBuffer, 1, (DSPComplex *) systemSamples, 2, 1024);
				if([audioThread running] == YES)
					[audioBuffer put:systemSampleData];
				
				samples = 0;
				
			}
		}
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

-(void)setFrequency: (int)_frequency forReceiver: (int)_receiver {
	receiverFrequency[_receiver] = _frequency;
}

-(int)getFrequency: (int)_receiver {
	return receiverFrequency[_receiver];
}

-(void)setSampleRate: (int) _sampleRate {
	sampleRate = _sampleRate;
	switch(sampleRate){
		case 48000:
			outputSampleIncrement = 1;
			break;
		case 96000:
			outputSampleIncrement = 2;
			break;
		case 192000:
			outputSampleIncrement = 4;
			break;
		default:
			outputSampleIncrement = 1;
			break;
	}
}

-(void)setSystemAudio: (BOOL)_systemAudio {
	if(systemAudio == FALSE && _systemAudio == TRUE) {
		audioThread = [[SystemAudioThread alloc] initWithBuffer:audioBuffer];
		[audioThread start];
	} else if (systemAudio == TRUE && _systemAudio == FALSE) {
		audioThread.running = FALSE;
	}
	
	systemAudio = _systemAudio;
}

-(void)setOpenCollectors:(UInt8)collectorSetting {
	openCollectors = collectorSetting & 0xFE;
}

-(void)notifyBandscopeWatchers {
	[operationQueue addOperation:[NSBlockOperation blockOperationWithBlock: ^{
		[[NSNotificationCenter defaultCenter] postNotificationName:@"XTBandscopeDataReady" object:self];
	}]];
}

-(void)awakeFromNib {
	self.systemAudio = [[NSUserDefaults standardUserDefaults] boolForKey:@"systemAudio"];
}


-(void)sendDiscover {
	MetisDiscoveryRequest discovery;
	int bytesWritten;
	
	discovery.magic = htons(0xEFFE);
	discovery.opcode = 0x02;
	memset(&(discovery.padding), 0, sizeof(discovery.padding));
	
	struct sockaddr_in broadcastAddressStruct;
	broadcastAddressStruct.sin_len = sizeof(broadcastAddressStruct);
	broadcastAddressStruct.sin_family = AF_INET;
	broadcastAddressStruct.sin_port = htons(1024);
	broadcastAddressStruct.sin_addr.s_addr = htonl(INADDR_BROADCAST);
	
	int yes = 1;
	setsockopt(CFSocketGetNative(metisSocket), SOL_SOCKET, SO_BROADCAST, (void *)&yes, sizeof(yes));
	
	bytesWritten = sendto(CFSocketGetNative(metisSocket), 
						  &discovery, 
						  sizeof(discovery), 
						  0,
						  (struct sockaddr *) &broadcastAddressStruct, 
						  sizeof(broadcastAddressStruct));
	
	if(bytesWritten == -1) {
		NSLog(@"[%@ %s] Network Write Failed: %s\n", [self class], (char *) _cmd, strerror(errno));
		return;
	}
	
	if(bytesWritten != sizeof(discovery)) {
		NSLog(@"[%@ %s] Short write to network\n", [self class], (char *) _cmd);
		return;
	}
}

-(void)performDiscovery {
	int discoverySocket;
	BOOL gotDiscovery = NO;
	MetisDiscoveryReply reply;
	struct sockaddr_in replyAddress;
	socklen_t replyAddressLen;
	int bytesReceived;
	
	discoverySocket = socket(PF_INET, SOCK_DGRAM, IPPROTO_UDP);
	if(discoverySocket == -1) { 
		NSLog(@"[%@ %s] Creating discovery socket failed: %s\n", [self class], (char *) _cmd, strerror(errno));
		return;
	}
	
	struct timeval timeout;
	timeout.tv_sec = 1;
	timeout.tv_usec = 0;
	
	if(setsockopt(discoverySocket, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout)) == -1) {
		NSLog(@"[%@ %s] Setting receive timeout failed: %s\n", [self class], (char *) _cmd, strerror(errno));
		return;
	}
	
	struct sockaddr_in discoveryAddress;
	discoveryAddress.sin_len = sizeof(discoveryAddress);
	discoveryAddress.sin_family = AF_INET;
	discoveryAddress.sin_port = htons(1025);
	discoveryAddress.sin_addr.s_addr = htonl(INADDR_ANY);
	
	if(bind(discoverySocket, (struct sockaddr *) &discoveryAddress, sizeof(discoveryAddress)) == -1) {
		NSLog(@"[%@ %s] Binding discovery socket failed: %s\n", [self class], (char *) _cmd, strerror(errno));
		return;
	}		
	
	while(gotDiscovery == NO) {
		char ipAddr[32];
		
		[self sendDiscover];		
		
		replyAddressLen = sizeof(replyAddress);
		bytesReceived = recvfrom(discoverySocket, 
								 &reply, 
								 sizeof(reply), 
								 0, 
								 (struct sockaddr *) &replyAddress, 
								 &replyAddressLen);
		
		if(bytesReceived == -1) {
			NSLog(@"[%@ %s] Network read failed: %s\n", [self class], (char *) _cmd, strerror(errno));
			continue;
		}
		
		if(ntohs(reply.magic) == 0xEFFE && reply.opcode == 0x02) {
			if(replyAddress.sin_addr.s_addr == 0) {
				NSLog(@"[%@ %s] Null IP address received\n", [self class], (char *) _cmd);
				sleep(1);
				continue;
			}
			if(inet_ntop(AF_INET, &(replyAddress.sin_addr.s_addr), ipAddr, 32) == NULL) {
				NSLog(@"[%@ %s] Could not parse IP address: %s\n", [self class], (char *) _cmd, strerror(errno));
			} else {
				NSLog(@"[%@ %s] Discovered Metis at: %s:%d\n", [self class], (char *) _cmd, ipAddr, ntohs(replyAddress.sin_port));
				metisAddressStruct.sin_addr.s_addr = replyAddress.sin_addr.s_addr;
				running = YES;
				[NSThread detachNewThreadSelector:@selector(processingLoop) toTarget:self withObject:nil];
				[NSThread detachNewThreadSelector:@selector(socketServiceLoop) toTarget:self withObject:nil];
				[NSThread detachNewThreadSelector:@selector(socketWriteLoop) toTarget:self withObject:nil];
				[self kickStart];
				
				gotDiscovery = YES;
			}
		} else {
			if(inet_ntop(AF_INET, &(reply.ip), ipAddr, 32) == NULL) {
				NSLog(@"[%@ %s] Invalid packet from unknown IP: %s\n", [self class], (char *) _cmd, strerror(errno));
			} else {				
				NSLog(@"[%@ %s] Invalid packet received from %s magic = %#hx opcode = %#hhx.\n", [self class], (char *) _cmd, ipAddr, reply.magic, reply.opcode);
			}
		}
	}
	close(discoverySocket);
}

-(void) start {
	int bytesWritten;
	MetisStartStop startPacket;
	
	[self performDiscovery];
	
	startPacket.magic = htons(0xEFFE);
	startPacket.opcode = 0x04;
	startPacket.startStop = 0x01;
	memset(&(startPacket.padding), 0, sizeof(startPacket.padding));
	
	bytesWritten = sendto(CFSocketGetNative(metisSocket),
						  &startPacket,
						  sizeof(startPacket),
						  0,
						  (struct sockaddr *) &metisAddressStruct,
						  sizeof(metisAddressStruct));
	
	if(bytesWritten == -1) {
		NSLog(@"[%@ %s] Network write failed: %s\n", [self class], (char *) _cmd, strerror(errno));
		return;
	}
	
	if(bytesWritten != sizeof(startPacket)) {
		NSLog(@"[%@ %s] Short write to network.\n", [self class], (char *) _cmd);
		return;
	}
}

-(void) stop {
	MetisStartStop stopPacket;
	int bytesWritten;
	
	stopPacket.magic = htons(0xEFFE);
	stopPacket.opcode = 0x04;
	stopPacket.startStop = 0x00;
	memset(&(stopPacket.padding), 0, sizeof(stopPacket.padding));
	
	bytesWritten = sendto(CFSocketGetNative(metisSocket),
						  &stopPacket,
						  sizeof(stopPacket),
						  0,
						  (struct sockaddr *) &metisAddressStruct,
						  sizeof(metisAddressStruct));
	
	if(bytesWritten == -1) {
		NSLog(@"[%@ %s] Network write failed: %s\n", [self class], (char *) _cmd, strerror(errno));
		return;
	}
	
	if(bytesWritten != sizeof(stopPacket)) {
		NSLog(@"[%@ %s] Short write to network.\n", [self class], (char *) _cmd);
		return;
	}
	
	running = NO;
}	


-(void)kickStart {
	MetisPacket packet;
	int bytesWritten;
	
	packet.header.magic = htons(0xEFFE);
	packet.header.opcode = 0x01;
	packet.header.endpoint = 0x02;
	packet.packets[0].magic[0] = SYNC;
	packet.packets[0].magic[1] = SYNC;
	packet.packets[0].magic[2] = SYNC;
	packet.packets[1].magic[0] = SYNC;
	packet.packets[1].magic[1] = SYNC;
	packet.packets[1].magic[2] = SYNC;	
	
	for(int i = 0; i < 8; ++i) {
		packet.header.sequence = htonl(metisWriteSequence++);
		memset(packet.packets[0].samples, 0, sizeof(OzySamplesOut) * 63);
		memset(packet.packets[1].samples, 0, sizeof(OzySamplesOut) * 63);
		[self fillHeader:packet.packets[0].header];
		[self fillHeader:packet.packets[1].header];
		
		bytesWritten = sendto(CFSocketGetNative(metisSocket), 
							  &packet, 
							  sizeof(MetisPacket), 
							  0, 
							  (struct sockaddr *) &metisAddressStruct, 
							  sizeof(metisAddressStruct));
		
		if(bytesWritten == -1) {
			NSLog(@"[%@ %s] Network Write Failed: %s\n", [self class], (char *) _cmd, strerror(errno));
			continue;
		}
		
		if(bytesWritten != sizeof(MetisPacket)) {
			NSLog(@"[%@ %s] Short write to network.\n", [self class], (char *) _cmd);
			continue;
		}		
	}
}	

-(void)socketServiceLoop {
	struct thread_time_constraint_policy ttcpolicy;
	mach_timebase_info_data_t tTBI;
	double mult;
	
	struct sockaddr_in packetFromAddress;
	socklen_t addressLength;
	
	ssize_t bytesRead;
	
	mach_timebase_info(&tTBI);
	mult = ((double)tTBI.denom / (double)tTBI.numer) * 1000000;
	
	ttcpolicy.period = 12 * mult;
	ttcpolicy.computation = 2 * mult;
	ttcpolicy.constraint = 24 * mult;
	ttcpolicy.preemptible = 0;
	
	if((thread_policy_set(mach_thread_self(), THREAD_TIME_CONSTRAINT_POLICY, (thread_policy_t) &ttcpolicy, THREAD_TIME_CONSTRAINT_POLICY_COUNT)) != KERN_SUCCESS) {
		NSLog(@"[OzyIOCallbackThread main]:  Failed to set callback to realtime\n");
	} 	
	
	while(running == YES) {
		
		NSMutableData *newBuffer = [ep6Buffers getFreeBuffer];
		if(newBuffer == nil) {
			NSLog(@"[%@ %s] Couldn't get a free buffer\n", [self class], (char *) _cmd);
			continue;
		}
		
		bytesRead = recvfrom(CFSocketGetNative(metisSocket), 
							 (void *) [newBuffer mutableBytes], 
							 [newBuffer length], 
							 0, 
							 (struct sockaddr *) &packetFromAddress, 
							 &addressLength);
		
		if(bytesRead == -1) {
			NSLog(@"[%@ %s] Network Read Failed: %s\n", [self class], (char *) _cmd, strerror(errno));
			[ep6Buffers freeBuffer:newBuffer];
			continue;
		}
		
		if(bytesRead != [newBuffer length]) {
			NSLog(@"[%@ %s] Short read from network.\n", [self class], (char *) _cmd);
			[ep6Buffers freeBuffer:newBuffer];
			continue;
		}
		
		[ep6Buffers putInputBuffer:newBuffer];
		semaphore_signal([ep6Buffers ozyInputBufferSemaphore]);
	}
}

-(void)socketWriteLoop {
	struct thread_time_constraint_policy ttcpolicy;
	mach_timebase_info_data_t tTBI;
	double mult;
	NSMutableData *packetData = [NSMutableData dataWithLength:sizeof(MetisPacket)];
	MetisPacket *packet = (MetisPacket *) [packetData mutableBytes];
	NSData *bufferData;
	int bytesWritten;
	
	mach_timebase_info(&tTBI);
	mult = ((double)tTBI.denom / (double)tTBI.numer) * 1000000;
	
	ttcpolicy.period = 12 * mult;
	ttcpolicy.computation = 2 * mult;
	ttcpolicy.constraint = 24 * mult;
	ttcpolicy.preemptible = 0;
	
	packet->header.magic = htons(0xEFFE);
	packet->header.opcode = 0x01;
	packet->header.endpoint = 0x02;
	packet->packets[0].magic[0] = SYNC;
	packet->packets[0].magic[1] = SYNC;
	packet->packets[0].magic[2] = SYNC;
	packet->packets[1].magic[0] = SYNC;
	packet->packets[1].magic[1] = SYNC;
	packet->packets[1].magic[2] = SYNC;
		
	if((thread_policy_set(mach_thread_self(), THREAD_TIME_CONSTRAINT_POLICY, (thread_policy_t) &ttcpolicy, THREAD_TIME_CONSTRAINT_POLICY_COUNT)) != KERN_SUCCESS) {
		NSLog(@"[OzyIOCallbackThread main]:  Failed to set callback to realtime\n");
	} 	
	NSLog(@"Beginning write thread\n");
	
	while(running == YES) {
		bufferData = [outputBuffer waitForSize:sizeof(packet->packets[0].samples) * 2];
		const unsigned char *buffer = [bufferData bytes];
		
		mox = NO;
		for(int i = 5; i < [bufferData length]; i += 8)
			if(buffer[i] != 0x00) {
				mox = YES;
				NSLog(@"MOX!\n");
				break;
			}
			
		packet->header.sequence = htonl(metisWriteSequence++);	
		[self fillHeader:packet->packets[0].header];
		[self fillHeader:packet->packets[1].header];

		memcpy(packet->packets[0].samples, buffer, sizeof(packet->packets[0].samples));
		memcpy(packet->packets[1].samples, buffer + sizeof(packet->packets[0].samples), sizeof(packet->packets[0].samples));
		
		bytesWritten = sendto(CFSocketGetNative(metisSocket), 
							  packet, 
							  sizeof(MetisPacket), 
							  0, 
							  (struct sockaddr *) &metisAddressStruct, 
							  sizeof(metisAddressStruct));
		
		if(bytesWritten == -1) {
			NSLog(@"[%@ %s] Network Write Failed: %s\n", [self class], (char *) _cmd, strerror(errno));
			continue;
		}
		
		if(bytesWritten != sizeof(MetisPacket)) {
			NSLog(@"[%@ %s] Short write to network.\n", [self class], (char *) _cmd);
			continue;
		}
	}
	
	NSLog(@"Write Loop ends\n");
}

-(void)processingLoop {
	struct thread_time_constraint_policy ttcpolicy;
	mach_timebase_info_data_t tTBI;
	double mult;
	
	mach_timebase_info(&tTBI);
	mult = ((double)tTBI.denom / (double)tTBI.numer) * 1000000;
	
	ttcpolicy.period = 12 * mult;
	ttcpolicy.computation = 2 * mult;
	ttcpolicy.constraint = 24 * mult;
	ttcpolicy.preemptible = 0;
	
	if((thread_policy_set(mach_thread_self(), THREAD_TIME_CONSTRAINT_POLICY, (thread_policy_t) &ttcpolicy, THREAD_TIME_CONSTRAINT_POLICY_COUNT)) != KERN_SUCCESS) {
		NSLog(@"[OzyIOCallbackThread main]:  Failed to set callback to realtime\n");
	} 	
	
	[[NSThread currentThread] setName:@"Endpoint 6 Processing"];
	
	while(running == YES) {
		
		semaphore_wait([ep6Buffers ozyInputBufferSemaphore]);
		
		NSData *dataBuffer = [ep6Buffers getInputBuffer];
		
		if(dataBuffer == nil) {
			NSLog(@"[%@ %s] Couldn't get an input buffer\n", [self class], (char *) _cmd);
			continue;
		}
		
		MetisPacket *buffer = (MetisPacket *) [dataBuffer bytes];
		
		if(ntohs(buffer->header.magic) == 0xEFFE) {
			switch(buffer->header.endpoint) {
				case 6:
					[self processInputBuffer:dataBuffer];
					break;
			}
		} else {
			NSLog(@"[%@ %s] Invalid packet received: %@\n", [self class], (char *) _cmd, dataBuffer);
		}
		
		[ep6Buffers freeBuffer:dataBuffer];
		
	}
}

@end