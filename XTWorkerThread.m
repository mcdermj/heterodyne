//
//  XTWorkerThread.m
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

#import "XTWorkerThread.h"

#include <mach/mach_time.h>
#include <mach/thread_policy.h>

kern_return_t   thread_policy_set(
                                  thread_t                                        thread,
                                  thread_policy_flavor_t          flavor,
                                  thread_policy_t                         policy_info,
                                  mach_msg_type_number_t          count);

@implementation XTWorkerThread

@synthesize runLoop;
@synthesize running;
@synthesize realtime;

-(id)init {
    return [self initWithRealtime:NO];
}

-(id)initWithRealtime:(BOOL)newRealtime {
    self = [super init];
    
    if(self) {
        running = YES;
        realtime = newRealtime;
    }
    
    return self;
}

-(void)main {
    struct thread_time_constraint_policy ttcpolicy;
	mach_timebase_info_data_t tTBI;
	double mult;

	runLoop = [NSRunLoop currentRunLoop];
    
    if(realtime) {
        mach_timebase_info(&tTBI);
        mult = ((double)tTBI.denom / (double)tTBI.numer) * 1000000;
        
        ttcpolicy.period = 12 * mult;
        ttcpolicy.computation = 2 * mult;
        ttcpolicy.constraint = 24 * mult;
        ttcpolicy.preemptible = 0;
        
        if((thread_policy_set(mach_thread_self(), THREAD_TIME_CONSTRAINT_POLICY, (thread_policy_t) &ttcpolicy, THREAD_TIME_CONSTRAINT_POLICY_COUNT)) != KERN_SUCCESS) {
            NSLog(@"[%@ %s]:  Failed to set realtime priority\n", [self class], (char *) _cmd);
        } 
    }
	
	//  You need a dummy port added to the run loop so that the thread doesn't freak out
	[[NSRunLoop currentRunLoop] addPort:[NSMachPort port] forMode:NSDefaultRunLoopMode];
	
	while(running == TRUE) {
		[[NSRunLoop	currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
	}
}

@end
