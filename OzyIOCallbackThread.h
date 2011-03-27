//
//  OzyIOCallbackThread.h
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

#import <mach/mach_time.h>
#import <mach/thread_policy.h>
#import <mach/mach_init.h>

@class OzyInterface;

@interface OzyIOCallbackThread : NSThread {
	NSRunLoop *runLoop;
	
	OzyInterface *interface;
	
	BOOL FXLoaded, FPGALoaded;
}

-(void) main;

-(void)removedCallback: (io_service_t) ozyDevice;
-(void)matchedCallback: (io_service_t) ozyDevice;

@property (readonly) NSRunLoop *runLoop;
@property OzyInterface *interface;

@end

void matched_callback(void *inputData, io_iterator_t iterator);
void removed_callback(void *inputData, io_iterator_t iterator);