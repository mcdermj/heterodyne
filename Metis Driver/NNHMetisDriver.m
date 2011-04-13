//
//  NNHMetisDriver.m
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

#import "NNHMetisDriver.h"

#import "XTDTTSP.h"
#import "XTDSPBlock.h"

#include <arpa/inet.h>
#include <mach/mach_time.h>
#include <sys/time.h>

@implementation NNHMetisDriver

@synthesize ep4Buffers;
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
@synthesize sdr;

+(NSString *)name {
	return @"Metis Driver";
}

+(float)version {
	return 1.0;
}

+(NSString *)versionString {
	return [NSString stringWithFormat:@"%0.1f", [NNHMetisDriver version]];
}

+(NSImage *)icon {
	NSBundle *myBundle = [NSBundle bundleForClass:[self class]];
	
	return [[NSImage alloc] initWithContentsOfFile:[myBundle pathForResource:[myBundle objectForInfoDictionaryKey:@"CFBundleIconFile"] ofType:@"icns"]];
}

+(NSString *)IDString {
	return [NSString stringWithFormat:@"%@ v%0.1f", [NNHMetisDriver name], [NNHMetisDriver version]];
}

-(void)loadParams {
	dither = [[NSUserDefaults standardUserDefaults] boolForKey:@"MetisDriver.dither"];
	random = [[NSUserDefaults standardUserDefaults] boolForKey:@"MetisDriver.random"];
	tenMHzSource = [[NSUserDefaults standardUserDefaults] integerForKey:@"MetisDriver.tenMHzSource"];
	oneTwentyTwoMHzSource = [[NSUserDefaults standardUserDefaults] integerForKey:@"MetisDriver.oneTwentyTwoMHzSource"];
	mercuryPresent = [[NSUserDefaults standardUserDefaults] boolForKey:@"MetisDriver.mercuryPresent"];
	penelopePresent = [[NSUserDefaults standardUserDefaults] boolForKey:@"MetisDriver.penelopePresent"];
	micGain = [[NSUserDefaults standardUserDefaults] floatForKey:@"MetisDriver.micGain"];
	txGain = [[NSUserDefaults standardUserDefaults] floatForKey:@"MetisDriver.txGain"];
    lineIn = [[NSUserDefaults standardUserDefaults] boolForKey:@"MetisDriver.lineIn"];
    micBoost = [[NSUserDefaults standardUserDefaults] boolForKey:@"MetisDriver.micBoost"];
	[self setSampleRate:[[NSUserDefaults standardUserDefaults] integerForKey:@"MetisDriver.sampleRate"]];
	
	
	openCollectors = 0x00;
	for (int i = 1; i < 8; ++i) {
		NSString *collectorName = [NSString stringWithFormat:@"MetisDriver.oc%d", i];
		if([[NSUserDefaults standardUserDefaults] boolForKey:collectorName] == YES) {
			openCollectors |= (UInt8) (0x01 << i);
		}
	}
}

-(id)initWithSDR:(XTDTTSP *)newSdr
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
		
		stopDiscovery = NO;
		
		transmitterFrequency = receiverFrequency[0] = 0;
		
		NSDictionary *driverDefaults = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle bundleForClass:[self class]] pathForResource:@"MetisDefaults" ofType:@"plist"]];

		[[NSUserDefaults standardUserDefaults] registerDefaults:driverDefaults];
		
		operationQueue = [[NSOperationQueue alloc] init];
		
		ep4Buffers = [[OzyInputBuffers alloc] initWithSize:BANDSCOPE_BUFFER_SIZE quantity: 16];
		outputBuffer = [[OzyRingBuffer alloc] initWithEntries:(8 * sizeof(MetisPacket)) andName:@"Metis Output Buffer"];
				
		[[NSNotificationCenter defaultCenter] addObserver:self selector: @selector(loadParams) name: NSUserDefaultsDidChangeNotification object: nil];

		[self loadParams];
				
		sampleData = [NSMutableData dataWithLength:sizeof(OzySamplesOut) * 128];
		outBuffer = (OzySamplesOut *) [sampleData mutableBytes];		
		
		//  Create a socket to communicate with Metis
		metisSocket = socket(PF_INET, SOCK_DGRAM, 0);
		
		//  Bind it to port 1024
		struct sockaddr_in bindAddress;
		bindAddress.sin_len = sizeof(bindAddress);
		bindAddress.sin_family = AF_INET;
		bindAddress.sin_port = 0;
		bindAddress.sin_addr.s_addr = htonl(INADDR_ANY);
		
		
		if(bind(metisSocket, (struct sockaddr *) &bindAddress, sizeof(bindAddress)) == -1)
			NSLog(@"[%@ %s]: Couldn'g bind socket: %s\n", [self class], (char *) _cmd, strerror(errno));
		
		metisAddressStruct.sin_len = sizeof(metisAddressStruct);
		metisAddressStruct.sin_family = AF_INET;
		metisAddressStruct.sin_port = htons(1024);
		
		metisWriteSequence = 0;
		
		sdr = newSdr;
        
        processingBlock = [XTDSPBlock dspBlockWithBlockSize:1024]; 
	}
	
	return self;
}

-(void)processInputBuffer:(NSData *)buffer {
    int c = 0;
	int k = 0;
	
	OzyPacket *currentOzyPacket;
	OzySamplesIn *inSamples;
    
    float *realSamples = [processingBlock realElements];
    float *imaginarySamples = [processingBlock imaginaryElements];
		
	MetisPacket *packet = (MetisPacket *) [buffer bytes];
	
	for(int i = 0; i < 2; ++i) {
		currentOzyPacket = &(packet->packets[i]);
		
		if(currentOzyPacket->magic[0] != SYNC || currentOzyPacket->magic[1] != SYNC || currentOzyPacket->magic[2] != SYNC) {
			NSLog(@"[%@ %s] Invalid Ozy packet received from Metis\n", [self class], (char *) _cmd);
			continue;
		}
		
		ptt = (currentOzyPacket->header[0] & 0x01) ? YES : NO;
		dash = (currentOzyPacket->header[0] & 0x02) ? YES : NO;
		dot = (currentOzyPacket->header[0] & 0x04) ? YES : NO;
		
		switch(currentOzyPacket->header[0] >> 3) {
			case 0x00:
				ADCOverflow = (currentOzyPacket->header[1] & 0x01) ? YES : NO;
				if(mercuryVersion != currentOzyPacket->header[2]) {
					[self willChangeValueForKey:@"mercuryVersion"];
					mercuryVersion = currentOzyPacket->header[2];
					[self didChangeValueForKey:@"mercuryVersion"];
				}
				if(penelopeVersion != currentOzyPacket->header[3]) {
					[self willChangeValueForKey:@"penelopeVersion"];
					penelopeVersion = currentOzyPacket->header[3];
					[self didChangeValueForKey:@"penelopeVersion"];
				}
				if(ozyVersion != currentOzyPacket->header[4]) {
					[self willChangeValueForKey:@"ozyVersion"];
					ozyVersion = currentOzyPacket->header[4];
					[self didChangeValueForKey:@"ozyVersion"];
				}
				break;
			case 0x01:
				forwardPower = (currentOzyPacket->header[1] << 8) + currentOzyPacket->header[2];
                // Alex/Apollo forward power in header[3] & header[4]
				break;
            case 0x02:
                // Reverse power from Alex/Apollo in header[1] & header[2]
                // AIN3 from Penny/Hermes in header[3] & header[4]
                break;
            case 0x03:
                //  AIN4 from Penny/Hermes in header[1] & header[2]
                //  AIN6 from Penny/Hermes in header[3] & header[4] (13.8V on Hermes)
                break;
            case 0x04:
                //  Don't know what this is yet?!
                break;
			default:
				NSLog(@"[%@ %s] Invalid Ozy packet header: %01x\n", [self class], (char *) _cmd, currentOzyPacket->header[0]);
				continue;
		}
		
		for(int j = 0; j < 63; ++j) {
			inSamples = &(currentOzyPacket->samples[j]);
			realSamples[samples] = (float)((signed char) inSamples->i[0] << 16 |
											   (unsigned char) inSamples->i[1] << 8 |
											   (unsigned char) inSamples->i[2]) / 8388607.0f;
			imaginarySamples[samples] = (float)((signed char) inSamples->q[0] << 16 |
												(unsigned char) inSamples->q[1] << 8 |
												(unsigned char) inSamples->q[2]) / 8388607.0f;
			leftMicBuffer[samples] = rightMicBuffer[samples] = (float)(CFSwapInt16BigToHost(inSamples->mic)) / 32767.0f * micGain;
            if(realSamples[samples] > 1.0f || imaginarySamples[samples] > 1.0f) {
                NSLog(@"Samples exceed max: %f %f\n", realSamples[samples], imaginarySamples[samples]);
            }
			++samples;
			
			if(samples == DTTSP_BUFFER_SIZE) {
                [sdr processBlock:processingBlock];
				//[sdr audioCallbackForThread: 0 realIn:leftInputBuffer imagIn:rightInputBuffer realOut:leftOutputBuffer imagOut:rightOutputBuffer size:DTTSP_BUFFER_SIZE];
				
				if(ptt == YES) {
					// memset(rightMicBuffer, 0, DTTSP_BUFFER_SIZE);
					[sdr audioCallbackForThread: 1 realIn:leftMicBuffer imagIn:rightMicBuffer realOut:leftTxBuffer imagOut:rightTxBuffer size:DTTSP_BUFFER_SIZE];
				}
				
				for(k = 0; k < DTTSP_BUFFER_SIZE; k += outputSampleIncrement) {
					outBuffer[c].leftRx = CFSwapInt16HostToBig((int16_t)(realSamples[k] * 32767.0f));
					outBuffer[c].rightRx = CFSwapInt16HostToBig((int16_t)(imaginarySamples[k] * 32767.0f));
					
					if(ptt == YES) {
						outBuffer[c].leftTx = CFSwapInt16HostToBig((int16_t) (leftTxBuffer[k] * 32767.0f * txGain));
						outBuffer[c].rightTx = CFSwapInt16HostToBig((int16_t) (rightTxBuffer[k] * 32767.0f * txGain));
					} else {
						outBuffer[c].leftTx = 0;
						outBuffer[c].rightTx = 0;
					}
					
					++c;
					
					if(c == 128) {
						[outputBuffer put:sampleData];
						c = 0;
					}
				}
								
				samples = 0;
                [processingBlock clearBlock];
				
			}
		}
	}
}

-(void)fillHeader:(char *)header {
	
	memset(header, 0, 5);
	
	switch(headerSequence) {
		case 0:
			if(mox) {
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
			
			if(penelopePresent) {
				header[1] |= 0x20;
			} 			
			if (mercuryPresent) {
				header[1] |= 0x40;
			}
			
			if(micSource == PENELOPE) {
				header[1] |= 0x80;
			}
			
			if(classE) {
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
			
			if(preamp) {
				header[3] |= 0x04;
			}
			
			if(dither) {
				header[3] |= 0x08;
			}
			
			if(random) {
				header[3] |= 0x10;
			}
			
			if(alexAntenna == 1) {
				header[3] |= 0x20;
			} else if(alexAntenna == 2) {
				header[3] |= 0x40;
			} else if(alexAntenna == XVERTER) {
				header[3] |= 0x60;
			}
			
			if(alexRxOut) {
				header[3] |= 0x80;
			}
			
			if(alexTxRelay == 1) {
				header[4] = 0x00;
			} else if(alexTxRelay == 2) {
				header[4] = 0x01;
			} else if(alexTxRelay == 3) {
				header[4] = 0x02;
			}
			
			if(duplex) {
				header[4] |= 0x04;
			}
			
			// handle number of receivers here
			
			++headerSequence;
			break;
		case 1:
			header[0] = 0x02;
			
			if(mox) {
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
			
			if(mox) {
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
			
			if(mox) {
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
			
			if(mox) {
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
			
			if(mox) {
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
			
			if(mox) {
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
			
			if(mox) {
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
			
			if(mox) {
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
			
			if(mox) {
				header[0] |= 0x01;
			}
			
			header[1] = driveLevel;
			
			if(micBoost) {
				header[2] = 0x01;
			}
            
            if(lineIn) {
                header[2] |= 0x02;
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
	if(sampleRate == _sampleRate) return;
	
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

-(void)setOpenCollectors:(UInt8)collectorSetting {
	openCollectors = collectorSetting & 0xFE;
}

-(void)notifyBandscopeWatchers {
	[operationQueue addOperation:[NSBlockOperation blockOperationWithBlock: ^{
		[[NSNotificationCenter defaultCenter] postNotificationName:@"XTBandscopeDataReady" object:self];
	}]];
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
	setsockopt(metisSocket, SOL_SOCKET, SO_BROADCAST, (void *)&yes, sizeof(yes));
	
	bytesWritten = sendto(metisSocket, 
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
	
	for(int i = 0; i < 32; ++i) {
		packet.header.sequence = htonl(metisWriteSequence++);
		memset(packet.packets[0].samples, 0, sizeof(OzySamplesOut) * 63);
		memset(packet.packets[1].samples, 0, sizeof(OzySamplesOut) * 63);
		[self fillHeader:packet.packets[0].header];
		[self fillHeader:packet.packets[1].header];
				
		bytesWritten = sendto(metisSocket, 
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

-(BOOL)performDiscovery {
	BOOL gotDiscovery = NO;
	MetisDiscoveryReply reply;
	struct sockaddr_in replyAddress;
	socklen_t replyAddressLen;
	int bytesReceived;
		
	struct timeval timeout;
	timeout.tv_sec = 1;
	timeout.tv_usec = 0;
	
	if(setsockopt(metisSocket, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout)) == -1) {
		NSLog(@"[%@ %s] Setting receive timeout failed: %s\n", [self class], (char *) _cmd, strerror(errno));
		return NO;
	}
		
	while(gotDiscovery == NO && stopDiscovery == NO) {
		char ipAddr[32];
		
		[self sendDiscover];		
		
		replyAddressLen = sizeof(replyAddress);
		bytesReceived = recvfrom(metisSocket, 
								 &reply, 
								 sizeof(reply), 
								 0, 
								 (struct sockaddr *) &replyAddress, 
								 &replyAddressLen);
		
		
		if(bytesReceived == -1) {
			if(errno == EAGAIN) {
				NSLog(@"[%@ %s]: Discovery timeout after 1 second, retrying\n", [self class], (char *) _cmd);
			} else {
				NSLog(@"[%@ %s] Network read failed: %s (%d)\n", [self class], (char *) _cmd, strerror(errno), errno);
			}
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
	
	timeout.tv_sec = 0;
	if(setsockopt(metisSocket, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout)) == -1) {
		NSLog(@"[%@ %s] Resetting receive timeout failed: %s\n", [self class], (char *) _cmd, strerror(errno));
		return NO;
	}	
	
	return gotDiscovery;
}

-(BOOL) sendStartPacket {
    int bytesWritten;
	MetisStartStop startPacket;

	startPacket.magic = htons(0xEFFE);
	startPacket.opcode = 0x04;
	startPacket.startStop = 0x01;
	memset(&(startPacket.padding), 0, sizeof(startPacket.padding));
	
	bytesWritten = sendto(metisSocket,
						  &startPacket,
						  sizeof(startPacket),
						  0,
						  (struct sockaddr *) &metisAddressStruct,
						  sizeof(metisAddressStruct));
    
    if(bytesWritten == -1) {
		NSLog(@"[%@ %s] Network write failed: %s\n", [self class], (char *) _cmd, strerror(errno));
		return NO;
	}
	
	if(bytesWritten != sizeof(startPacket)) {
		NSLog(@"[%@ %s] Short write to network.\n", [self class], (char *) _cmd);
		return NO;
	}

    return YES;
}

-(BOOL) start {
	
	stopDiscovery = NO;
	
	if([self performDiscovery] == NO) return NO;
	
	if([self sendStartPacket] == NO) 
        return NO;
    
	[self kickStart];
	[NSThread detachNewThreadSelector:@selector(socketServiceLoop) toTarget:self withObject:nil];
	[NSThread detachNewThreadSelector:@selector(socketWriteLoop) toTarget:self withObject:nil];	
	
	return YES;
}

-(BOOL) stop {
	MetisStartStop stopPacket;
	int bytesWritten;
	
	stopDiscovery = YES;
	
	stopPacket.magic = htons(0xEFFE);
	stopPacket.opcode = 0x04;
	stopPacket.startStop = 0x00;
	memset(&(stopPacket.padding), 0, sizeof(stopPacket.padding));
	
	bytesWritten = sendto(metisSocket,
						  &stopPacket,
						  sizeof(stopPacket),
						  0,
						  (struct sockaddr *) &metisAddressStruct,
						  sizeof(metisAddressStruct));
	
	if(bytesWritten == -1) {
		NSLog(@"[%@ %s] Network write failed: %s\n", [self class], (char *) _cmd, strerror(errno));
		return NO;
	}
	
	if(bytesWritten != sizeof(stopPacket)) {
		NSLog(@"[%@ %s] Short write to network.\n", [self class], (char *) _cmd);
		return NO;
	}
	
	running = NO;
	return YES;
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
		NSLog(@"[%@ %s]:  Failed to set realtime priority\n", [self class], (char *) _cmd);
	} 
	
	struct timeval timeout;
	timeout.tv_sec = 5;
	timeout.tv_usec = 0;	
	
	if(setsockopt(metisSocket, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout)) == -1) {
		NSLog(@"[%@ %s] Resetting receive timeout failed: %s\n", [self class], (char *) _cmd, strerror(errno));
	}
    
    NSMutableData *metisData = [NSMutableData dataWithLength:sizeof(MetisPacket)];
    MetisPacket *buffer = (MetisPacket *) [metisData bytes];
	
	while(running == YES) {
				
		bytesRead = recvfrom(metisSocket, 
							 (void *) buffer, 
							 sizeof(MetisPacket), 
							 0, 
							 (struct sockaddr *) &packetFromAddress, 
							 &addressLength);
		
		if(bytesRead == -1) {
			if(errno == EAGAIN) {
				NSLog(@"[%@ %s]: No data from Metis in 5 seconds, retrying\n", [self class], (char *) _cmd);
                [self sendStartPacket];
                [self kickStart];
			} else {
				NSLog(@"[%@ %s] Network Read Failed: %s\n", [self class], (char *) _cmd, strerror(errno));
			}
			continue;
		}
		
		if(bytesRead != sizeof(MetisPacket)) {
			NSLog(@"[%@ %s] Short read from network.\n", [self class], (char *) _cmd);
			continue;
		}
        
		if(ntohs(buffer->header.magic) == 0xEFFE) {
			switch(buffer->header.endpoint) {
				case 6:
					[self processInputBuffer:metisData];
					break;
			}
		} else {
			NSLog(@"[%@ %s] Invalid packet received: %@\n", [self class], (char *) _cmd, metisData);
		}
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
		NSLog(@"[%@ %s]:  Failed to set realtime priority\n", [self class], (char *) _cmd);
	} 	
	NSLog(@"[%@ %s]: Beginning write thread\n", [self class], (char *) _cmd);
	
	while(running == YES) {
		bufferData = [outputBuffer waitForSize:sizeof(packet->packets[0].samples) * 2];
		const unsigned char *buffer = [bufferData bytes];
		
		mox = NO;
		for(int i = 5; i < [bufferData length]; i += 8)
			if(buffer[i] != 0x00) {
				mox = YES;
				break;
			}
		
		packet->header.sequence = htonl(metisWriteSequence++);	
		[self fillHeader:packet->packets[0].header];
		[self fillHeader:packet->packets[1].header];
		
		memcpy(packet->packets[0].samples, buffer, sizeof(packet->packets[0].samples));
		memcpy(packet->packets[1].samples, buffer + sizeof(packet->packets[0].samples), sizeof(packet->packets[0].samples));
		
		bytesWritten = sendto(metisSocket, 
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

-(NSView *)configWindow {
	if(configWindow == nil) {
		if(![NSBundle loadNibNamed:@"NNHMetisDriver" owner:self] ) {
			NSLog(@"[%@ %s] Could not load config view bundle.\n", [self class], (char *) _cmd);

		}
	}
	
	if(configWindow == nil) {
		NSLog(@"[%@ %s] Config window isn't there!\n", [self class], (char *) _cmd);
	}
	
	return configWindow;
}

-(NSString *)metisIPAddressString {
	char ipString[16];
	
	if(inet_ntop(AF_INET, &(metisAddressStruct.sin_addr.s_addr), ipString, sizeof(ipString)) == NULL)
		strcpy(ipString, "0.0.0.0\0");

	return [NSString stringWithCString:ipString encoding: NSASCIIStringEncoding];
}

@end
