//
//  OzyInputBufferThread.m
//  MacHPSDR
//
//  Created by Jeremy McDermond on 2/13/10.
//  Copyright 2010 net.nh6z. All rights reserved.
//

#import "OzyInputBufferThread.h"


@implementation OzyInputBufferThread

-(id)initWithInterface:(OzyInterface *)_interface {
	
	self = [super init];
	
	if(self) {
		interface = _interface;
		[self setName:@"OzyInputBuffer"];
	}
	
	return self;
}

-(void) main {
	
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
	
	while(1) {
		// Wait for semaphore
		// This needs to get replaced by the run loop architecture
		semaphore_wait([[interface ep6Buffers] ozyInputBufferSemaphore]);
		
		NSData *ozyBuffer = [[interface ep6Buffers] getInputBuffer];
		if(ozyBuffer == NULL) {
			NSLog(@"OzyInputBufferThread: Couldn't get Ozy input buffer.\n");
		} else {
			if([ozyBuffer bytes] == NULL) {
				NSLog(@"Ozy buffer doesn't contain anything\n");
			}
			[interface processInputBuffer:ozyBuffer];
			[[interface ep6Buffers] freeBuffer:ozyBuffer];
		}
	}
}

@end
